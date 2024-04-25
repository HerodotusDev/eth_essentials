use alloy_primitives::{B256, BlockNumber, U256};
use alloy_provider::{Provider, ProviderBuilder, RootProvider};
use alloy_transport::{RpcError, TransportErrorKind};
use alloy_transport_http::Http;
use alloy_network::Ethereum;
use alloy_primitives::private::alloy_rlp;
use eth_trie_proofs::tx_trie::TxsMptHandler;
use alloy_rpc_client::RpcClient;
use alloy_rpc_types::BlockTransactions;
use reqwest::Client;
use serde::Serialize;
use serde_with::serde_as;
use alloy_primitives::hex::FromHex;
use std::fs::File;
use std::io::Write;
use eth_trie_proofs::tx_receipt_trie::TxReceiptsMptHandler;
use eth_trie_proofs::Error as TrieError;
use rand::Rng;

#[derive(Debug)]
enum Error {
    Trie(TrieError),
    Transport(TransportErrorKind),
    Rpc(RpcError<TransportErrorKind>),
}

struct Fetcher {
    provider: RootProvider<Ethereum, Http<Client>>,
    tx: TxsMptHandler,
    receipt: TxReceiptsMptHandler
}

#[derive(Debug, Serialize)]
enum ProofType {
    #[serde(rename = "tx_proof")]
    TxProof,
    #[serde(rename = "receipt_proof")]
    ReceiptProof,
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
    kind: ProofType,
}

impl Fetcher {
    fn new(rpc_url: &str) -> Result<Self, Error> {
        let http = Http::<Client>::new(rpc_url.clone().to_string().parse().unwrap());
        let provider = ProviderBuilder::<_, Ethereum>::new()
            .provider(RootProvider::new(RpcClient::new(http, true)));
        let tx = TxsMptHandler::new(rpc_url)?;
        let receipt = TxReceiptsMptHandler::new(rpc_url)?;
        Ok(Fetcher { provider, tx, receipt })
    }

    async fn generate_block_tx_proofs(&mut self, block_number: u64) -> Result<Vec<MptProof>, Error> {
        let tx_count = self.get_block_txs_count(block_number).await?;
        self.tx.build_tx_tree_from_block(block_number).await?;
        let mut proofs = vec![];
        for i in 0..tx_count {
            let trie_proof = self.tx.get_proof(i)?;
            let root = self.tx.get_root().unwrap();
            
            // ensure the proof is valid
            self.tx.verify_proof(i, trie_proof.clone())?;
            
            proofs.push(MptProof {
                proof: trie_proof,
                key: generate_key_le(i),
                root,
                kind: ProofType::TxProof,
            });
        }

        Ok(proofs)
    }

    async fn generate_block_receipt_proofs(&mut self, block_number: u64)-> Result<Vec<MptProof>, Error> {
        let tx_count = self.get_block_txs_count(block_number).await?;
        self.receipt.build_tx_receipts_tree_from_block(block_number).await?;
        let mut proofs = vec![];
        for i in 0..tx_count {
            let trie_proof = self.receipt.get_proof(i)?;
            let root = self.receipt.get_root()?;

            // ensure the proof is valid
            self.receipt.verify_proof(i, trie_proof.clone())?;
            
            proofs.push(MptProof {
                proof: trie_proof,
                key: generate_key_le(i),
                root,
                kind: ProofType::ReceiptProof,
            });
        }

        Ok(proofs)
    }

    async fn get_block_txs_count(&self, block_number: u64) -> Result<u64, Error> {
        let block = self.provider.get_block(block_number.into(), false).await?;
        match block.unwrap().transactions {
            BlockTransactions::Hashes(hashes) => {
                Ok(hashes.len() as u64)
            },
            _ => panic!()
        }
    }

    async fn generate_random_block_proofs(&mut self, num_blocks: u32) -> Result<Vec<MptProof>, Error> {
        let mut rng = rand::thread_rng();
        let mut proofs = vec![];

        // Fetch the current block number
        let current_block_number: u64 = self.provider.get_block_number().await?.into();
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
        }

        Ok(proofs)
    }
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    // Create a new Fetcher instance
    let mut fetcher = Fetcher::new("https://ethereum-rpc.publicnode.com")?;

    // Generate random block proofs
    let proofs = fetcher.generate_random_block_proofs(25).await?;

    // Export the proofs to a JSON file
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

fn generate_key_le(index: u64) -> Vec<u8> {
    alloy_rlp::encode(U256::from(index))
}

impl From<TrieError> for Error {
    fn from(error: TrieError) -> Self {
        Error::Trie(error)
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
