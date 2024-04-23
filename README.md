# EVM Libs Cairo

This repository contains a variety of cairo0 functions, useful when dealing with EVM related tasks. The repo contains the following:

- MPT (Merkle Patricia Trie): `verify_mpt_proof` verifies a Merkle Patricia Trie proof and returns the value if valid
- RLP (Recursive Length Prefix): contains a variety of different functions when dealing with RLP encoded data
- MMR (Merkle Mountain Range): useful stuff for working with MMRs
- Headers: functions for extracting header params from an rlp encoded EVM header

Please be sure to explore the `lib` directory, as the functions are well documented and should be easy to understand.

## Import Package

As these functions are written in cairo0, we rely on git submodules for using this package. Install this repo as a submodule in your project. 

E.g. like this:
```gitmodules
[submodule "packages/eth_essentials"]
  path = packages/eth_essentials
  url = https://github.com/HerodotusDev/eth_essentials.git
```

When compiling your program, it is important to set the `CAIRO_PATH` environment variable to the path of the `eth_essentials` directory. This is necessary for the compiler to find the imported functions. For the example above, this would look like this: `cairo-compile --cairo_path="packages/eth_essentials" ...`

Now the functions can be imported like this:

```python
from packages.eth-essentials.lib.utils import pow2alloc128
```

### Testing

Please ensure to expose a valid Ethereum mainnet RPC via an ENV variable `RPC_URL_MAINNET` before running the tests.

```bash
make ci-local
```
