def is_single_byte(prefix):
    """Check if the prefix indicates a single byte (0x00 to 0x7f)."""
    return 0x00 <= prefix <= 0x7F


def is_short_string(prefix):
    """Check if the prefix indicates a short string (0x80 to 0xb7)."""
    return 0x80 <= prefix <= 0xB7


def is_long_string(prefix):
    """Check if the prefix indicates a long string (0xb8 to 0xbf)."""
    return 0xB8 <= prefix <= 0xBF


def is_short_list(prefix):
    """Check if the prefix indicates a short list (0xc0 to 0xf7)."""
    return 0xC0 <= prefix <= 0xF7


def is_long_list(prefix):
    """Check if the prefix indicates a long list (0xf8 to 0xff)."""
    return 0xF8 <= prefix <= 0xFF


def write_word_to_memory(word: int, n: int, memory, ap) -> None:
    assert word < 2 ** (8 * n), f"Word value {word} exceeds {8 * n} bits."
    word_bytes = word.to_bytes(n, byteorder="big")
    for i in range(n):
        memory[ap + i] = word_bytes[i]
