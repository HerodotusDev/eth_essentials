use num_bigint::BigUint;
use starknet_crypto::poseidon_hash;
use tiny_keccak::{Hasher as KeccakTrait, Keccak as KeccakHasher};

pub trait Hasher {
    fn new() -> Self;
    fn hash(&self, x: &BigUint, y: &BigUint) -> BigUint;
}

pub struct Keccak;
impl Hasher for Keccak {
    fn new() -> Self {
        Self
    }

    fn hash(&self, x: &BigUint, y: &BigUint) -> BigUint {
        let mut keccak = KeccakHasher::v256();

        let mut result: Vec<u8> = Vec::new();

        let hex_x = format!("{:0>64}", x.to_str_radix(16));
        let bytes_x = hex::decode(hex_x).unwrap();
        result.extend(bytes_x);

        let hex_y = format!("{:0>64}", y.to_str_radix(16));
        let bytes_y = hex::decode(hex_y).unwrap();
        result.extend(bytes_y);

        keccak.update(&result);

        let mut output = [0u8; 32];
        keccak.finalize(&mut output);
        BigUint::from_bytes_be(&output)
    }
}

pub struct Poseidon;
impl Hasher for Poseidon {
    fn new() -> Self {
        Self
    }

    fn hash(&self, x: &BigUint, y: &BigUint) -> BigUint {
        poseidon_hash(x.try_into().unwrap(), y.try_into().unwrap()).to_biguint()
    }
}

#[derive(Debug)]
pub struct Mmr<H: Hasher> {
    hasher: H,
    nodes: Vec<BigUint>,
    leaf_count: usize,
}

impl<H: Hasher> Mmr<H> {
    pub fn new() -> Mmr<H> {
        Mmr {
            hasher: H::new(),
            nodes: vec![],
            leaf_count: 0,
        }
    }

    pub fn get_root(&self) -> BigUint {
        let mut peaks = self.retrieve_nodes(self.get_peaks());
        let mut hash = peaks.pop().unwrap();
        peaks
            .iter()
            .rev()
            .for_each(|x| hash = self.hasher.hash(x, &hash));
        self.hasher.hash(&self.size().into(), &hash)
    }

    pub fn size(&self) -> usize {
        self.nodes.len()
    }

    pub fn get_peaks(&self) -> Vec<usize> {
        let mut peaks = vec![];
        let mut node_count = self.nodes.len();
        if node_count == 0 {
            return vec![];
        }
        let height = node_count.ilog2() + 1;
        let mut offset = 0;
        for h in (1..=height).rev() {
            let subtree_size = 2_usize.pow(h) - 1;
            if subtree_size <= node_count {
                node_count -= subtree_size;
                offset += subtree_size;
                peaks.push(offset);
            }
        }
        assert!(node_count == 0, "Invalid node count");
        peaks
    }

    pub fn append(&mut self, element: BigUint) {
        let peaks = self.retrieve_nodes(self.get_peaks());
        let no_merged_peaks = self.leaf_count.trailing_ones();
        self.leaf_count += 1;
        self.nodes.push(element.clone());
        let mut last_node = element;
        for peak in peaks.iter().rev().take(no_merged_peaks as usize) {
            last_node = self.hasher.hash(&peak, &last_node);
            self.nodes.push(last_node.clone());
        }
    }

    pub fn retrieve_nodes(&self, indices: Vec<usize>) -> Vec<BigUint> {
        indices
            .iter()
            .map(|index| self.nodes[*index - 1].clone())
            .collect()
    }
}
