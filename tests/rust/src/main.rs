use alloy_network::Ethereum;

use alloy_primitives::private::alloy_rlp;
use alloy_primitives::{B256, U256};
use alloy_provider::{Provider, ProviderBuilder, RootProvider};
use alloy_rpc_client::RpcClient;
use alloy_rpc_types::{Block, BlockTransactions, Transaction};
use alloy_transport::{RpcError, TransportErrorKind};
use alloy_transport_http::Http;
use eth_trie::MemoryDB;
use eth_trie::{EthTrie, Trie, TrieError as EthTrieError};
use eth_trie_proofs::tx_receipt_trie::TxReceiptsMptHandler;
use eth_trie_proofs::tx_trie::TxsMptHandler;
use eth_trie_proofs::Error as TrieError;
use ethereum_types::H256;
use rand::{Rng, RngCore};
use rlp::encode;
use reqwest::Client;
use serde::Serialize;
use serde_with::serde_as;
use std::fs::File;
use std::io::Write;
use std::sync::Arc;
use tiny_keccak::{Hasher, Keccak};

#[derive(Debug)]
enum Error {
    Trie(TrieError),
    Transport(TransportErrorKind),
    Rpc(RpcError<TransportErrorKind>),
    EthTrie(EthTrieError),
}

struct Fetcher {
    provider: RootProvider<Ethereum, Http<Client>>,
    tx: TxsMptHandler,
    receipt: TxReceiptsMptHandler,
}

#[derive(Debug, Serialize)]
enum ProofType {
    #[serde(rename = "tx_proof")]
    TxProof,
    #[serde(rename = "receipt_proof")]
    ReceiptProof,
    #[serde(rename = "account_proof")]
    AccountProof,
}

#[serde_with::serde_as]
#[derive(Debug, Serialize)]
pub struct MptProof {
    #[serde_as(as = "serde_with::hex::Hex")]
    root: B256,
    #[serde_as(as = "Vec<serde_with::hex::Hex>")]
    proof: Vec<Vec<u8>>,
    #[serde_as(as = "serde_with::hex::Hex")]
    key: Vec<u8>,
    #[serde_as(as = "serde_with::hex::Hex")]
    value_hash: Vec<u8>,
    value_len: u16,
    kind: ProofType,
}

impl Fetcher {
    fn new(rpc_url: &str) -> Result<Self, Error> {
        let http = Http::<Client>::new(rpc_url.to_string().parse().unwrap());
        let provider = ProviderBuilder::<_, Ethereum>::new()
            .provider(RootProvider::new(RpcClient::new(http, true)));
        let tx = TxsMptHandler::new(rpc_url)?;
        let receipt = TxReceiptsMptHandler::new(rpc_url)?;
        Ok(Fetcher {
            provider,
            tx,
            receipt,
        })
    }

    async fn generate_block_tx_proofs(
        &mut self,
        block_number: u64,
    ) -> Result<Vec<MptProof>, Error> {
        let tx_count = self.get_block_txs_count(block_number).await?;
        self.tx.build_tx_tree_from_block(block_number).await?;
        let mut proofs = vec![];
        for i in 0..tx_count {
            let trie_proof = self.tx.get_proof(i)?;
            let root = self.tx.get_root().unwrap();

            // ensure the proof is valid
            let result = self.tx.verify_proof(i, trie_proof.clone())?;
            let (value_hash, value_len) = gen_payload_commitment(result);

            proofs.push(MptProof {
                proof: trie_proof,
                key: generate_key_from_index(i),
                root,
                kind: ProofType::TxProof,
                value_hash,
                value_len,
            });
        }

        Ok(proofs)
    }

    async fn generate_block_receipt_proofs(
        &mut self,
        block_number: u64,
    ) -> Result<Vec<MptProof>, Error> {
        let tx_count = self.get_block_txs_count(block_number).await?;
        self.receipt
            .build_tx_receipts_tree_from_block(block_number)
            .await?;
        let mut proofs = vec![];
        for i in 0..tx_count {
            let trie_proof = self.receipt.get_proof(i)?;
            let root = self.receipt.get_root()?;

            // ensure the proof is valid
            let result = self.receipt.verify_proof(i, trie_proof.clone())?;
            let (value_hash, value_len) = gen_payload_commitment(result);

            proofs.push(MptProof {
                proof: trie_proof,
                key: generate_key_from_index(i),
                root,
                kind: ProofType::ReceiptProof,
                value_hash,
                value_len,
            });
        }

        Ok(proofs)
    }

    async fn get_account_proofs(&mut self, block_number: u64) -> Result<Vec<MptProof>, Error> {
        let block = self.get_block(block_number).await?;

        // fetch all txs from the block
        let txs = self.get_block_txs(block_number).await?;

        // retrieve sender and receiver addresses
        let mut addresses = vec![];
        for tx in txs {
            addresses.push(tx.from);
            if let Some(to) = tx.to {
                addresses.push(to);
            }
        }

        let mut proofs = vec![];
        let memdb = Arc::new(MemoryDB::new(true));
        let trie = EthTrie::new(memdb.clone());

        for address in addresses {
            let proof: Vec<_> = self
                .provider
                .get_proof(address, vec![], Some(block_number.into()))
                .await?
                .account_proof
                .iter()
                .map(|x| x.as_ref().to_vec())
                .collect();

            // ensure the proof is valid
            let result = trie.verify_proof(
                H256::from_slice(block.header.state_root.as_slice()),
                generate_key_from_address(address.0.as_slice()).as_slice(),
                proof.clone(),
            )?;

            match result {
                Some(value) => {
                    let (value_hash, value_len) = gen_payload_commitment(value.to_vec());
                    proofs.push(MptProof {
                        proof,
                        key: generate_key_from_address(address.0.as_slice()),
                        root: block.header.state_root,
                        kind: ProofType::AccountProof,
                        value_hash,
                        value_len,
                    });
                }
                _ => panic!("Proof verification failed for address: {:?}", address),
            }
        }

        Ok(proofs)
    }

    async fn get_block(&self, block_number: u64) -> Result<Block, Error> {
        match self.provider.get_block(block_number.into(), false).await {
            Ok(Some(block)) => Ok(block),
            _ => panic!(),
        }
    }

    async fn get_block_txs(&self, block_number: u64) -> Result<Vec<Transaction>, Error> {
        let block = self.provider.get_block(block_number.into(), true).await?;
        match block.unwrap().transactions {
            BlockTransactions::Full(txs) => Ok(txs),
            _ => panic!(),
        }
    }

    async fn get_block_txs_count(&self, block_number: u64) -> Result<u64, Error> {
        let block = self.provider.get_block(block_number.into(), false).await?;
        match block.unwrap().transactions {
            BlockTransactions::Hashes(hashes) => Ok(hashes.len() as u64),
            _ => panic!(),
        }
    }

    async fn generate_random_block_proofs(
        &mut self,
        num_blocks: u32,
    ) -> Result<Vec<MptProof>, Error> {
        let mut rng = rand::thread_rng();
        let mut proofs = vec![];

        // Fetch the current block number
        let current_block_number: u64 = self.provider.get_block_number().await?;
        for _ in 0..num_blocks {
            // As there is a bug in the underlying alloy library, we need to start with the byzantium hardfork. https://github.com/alloy-rs/alloy/issues/630
            let block_number = rng.gen_range(4370000..current_block_number);
            println!("Selected block: {:?}", block_number);
            match self.generate_block_tx_proofs(block_number).await {
                Ok(proof) => proofs.extend(proof),
                Err(Error::Trie(TrieError::TxNotFound)) => continue, // found block no txs
                Err(e) => return Err(e),
            }

            match self.generate_block_receipt_proofs(block_number).await {
                Ok(proof) => proofs.extend(proof),
                Err(Error::Trie(TrieError::TxNotFound)) => continue, // found block no txs
                Err(e) => return Err(e),
            }

            let account_proofs = self.get_account_proofs(block_number).await?;
            proofs.extend(account_proofs);
        }

        Ok(proofs)
    }
}

fn gen_payload_commitment(value: Vec<u8>) -> (Vec<u8>, u16) {
    let mut hasher = Keccak::v256();
    hasher.update(value.as_ref());
    let mut output = [0u8; 32];
    hasher.finalize(&mut output);
    (output.to_vec(), value.len() as u16)
}

fn generate_byte_key_tests() -> Vec<MptProof> {
    let (mut trie, keys) = seed_test_trie();
    let mut proofs = vec![];
    let root = trie.root_hash().unwrap();
    for (i, key) in keys.iter().enumerate() {
        let proof = trie.get_proof(key.as_slice()).unwrap();
        let res = trie.verify_proof(root.clone(), key.as_slice(), proof.clone());
        match res {
            Ok(Some(value)) => {
                let (value_hash, value_len) = gen_payload_commitment(value.to_vec());
                proofs.push(MptProof {
                    proof,
                    key: key.clone(),
                    root: B256::from_slice(root.as_bytes()),
                    kind: ProofType::TxProof,
                    value_hash,
                    value_len,
                });
            },
            _ => panic!("Proof verification failed for key: {:?}", i),
        }
    }

    proofs
}

fn seed_test_trie() -> (EthTrie<MemoryDB>, Vec<Vec<u8>>) {
    let memdb = Arc::new(MemoryDB::new(true));
    let mut trie = EthTrie::new(memdb.clone());
    let mut keys = vec![];
    let mut key_bytes_len = 1;
    while key_bytes_len <= 32 {
        let mut key = vec![0u8; key_bytes_len];
        let mut value = vec![0u8; 32];
        let mut i = 0;

        // increase the permutations with a growing key size
        let permutations: u64 = 100 + key_bytes_len.pow(4) as u64;

        while i < permutations {
            rand::thread_rng().fill_bytes(&mut key);
            rand::thread_rng().fill_bytes(&mut value);
            let rlp_value = encode(&value);
            trie.insert(key.clone().as_slice(), rlp_value.as_ref()).unwrap();
            i += 1;
        }

        // The value we use for the test is rlp encoded
        rand::thread_rng().fill_bytes(&mut key);
        rand::thread_rng().fill_bytes(&mut value);
        let rlp_value = encode(&value);

        trie.insert(key.clone().as_slice(), rlp_value.as_ref()).unwrap();

        keys.push(key);
        key_bytes_len += 1;
    }

    return (trie, keys);
}


#[tokio::main]
async fn main() -> Result<(), Error> {
    // Create a new Fetcher instance
    let mut fetcher = Fetcher::new("")?;

    // Generate random block proofs
    // let proofs = fetcher.generate_random_block_proofs(5).await?;

    let proofs = generate_byte_key_tests();
    export_batch(proofs).unwrap();

    Ok(())
}

fn export_batch(proofs: Vec<MptProof>) -> Result<(), Error> {
    let chunks = proofs.chunks(50);

    for (i, chunk) in chunks.enumerate() {
        let serialized = serde_json::to_string_pretty(chunk).unwrap();

        // Write the JSON string to a file
        let mut file = File::create(format!("mpt_proofs_{}.json", i)).unwrap();
        file.write_all(serialized.as_bytes()).unwrap();
    }

    Ok(())
}
fn generate_key_from_address(address: &[u8]) -> Vec<u8> {
    let mut hasher = Keccak::v256();
    hasher.update(address);
    let mut output = [0u8; 32];
    hasher.finalize(&mut output);
    output.to_vec()
}

fn generate_key_from_index(index: u64) -> Vec<u8> {
    alloy_rlp::encode(U256::from(index))
}

impl From<TrieError> for Error {
    fn from(error: TrieError) -> Self {
        Error::Trie(error)
    }
}

impl From<EthTrieError> for Error {
    fn from(error: EthTrieError) -> Self {
        Error::EthTrie(error)
    }
}

impl From<TransportErrorKind> for Error {
    fn from(error: TransportErrorKind) -> Self {
        Error::Transport(error)
    }
}

impl From<RpcError<TransportErrorKind>> for Error {
    fn from(error: RpcError<TransportErrorKind>) -> Self {
        Error::Rpc(error)
    }
}
