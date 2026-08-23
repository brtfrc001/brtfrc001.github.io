---
title: "Cyber Apocalypse CTF 2026: The Salt Crown — 'False Witness' write-up"
categories: [ctf, cryptography]
tags: [ctf, write-up, cryptography, cyber-apocalypse, hack-the-box]
toc: true
math: true
mermaid: ture
---

Hi, This is a write-up for a challenge I solved in a CTF by Hack The Box.

Info:
- **Challenge:** `False Witness`
- **Category:** Cryptography
- **Difficulty:** Very Easy
- **Summary:** A server leaks key bits one by one and the user dynamically retrieves them.

## Challenge Description

"Caldrin Vowmark knows that not every seal deserves belief. Some marks still carry the weight of a living vow; others only imitate one well enough to pass a glance. She can question the realm's witnesses as many times as she likes, but certainty, it turns out, is much harder to earn than a convincing lie."

## Challenge code in server.py

Note: Preferably read the code before reading the writeup.

```python
from hashlib import sha256
from Crypto.Util.Padding import pad
from Crypto.Cipher import AES
import secrets

P = 0xCD4A96D3B7FA7251A1BB765933FB676FCAE8C9026682E34F779122DFD66915BB
FLAG = open("flag.txt", "rb").read().strip()
N = sha256().digest_size * 8

KEY = secrets.token_bytes(32)
KEY_BITS = list(map(int, f"{int.from_bytes(KEY):0256b}"))

def H(msg):
    return pow(G, msg, P)

class Oracle:
    def __init__(self):
        self.appeared = {}
    def oracle(self, i):
        if i in self.appeared:
            return self.appeared[i]
        else:
            ret = secrets.randbelow(2**N) if KEY_BITS[i] == 0 else PK[i % len(PK)][secrets.randbelow(2)]
            self.appeared[i] = ret
        return ret

def keygen():
    sk = [(secrets.randbelow(2**N), secrets.randbelow(2**N)) for _ in range(N)]
    pk = [(H(s[0]), H(s[1])) for s in sk]
    return sk, pk

print("Here is something for you:")
print(AES.new(KEY, AES.MODE_ECB).encrypt(pad(FLAG, 16)).hex())
while True:
    G = int(input("Before we start, give me the hashing generator: "))
    if 1 < G < P:
        break

SK, PK = keygen()
oracle = Oracle()
while True:
    print("1. Oracle")
    print("2. Exit")
    ch = input("> ")
    if ch == "1":
        offset_input = input("Enter offset: ")
        offset_input = offset_input.strip()
        if not offset_input:
            continue
        try:
            offset = int(offset_input)
        except ValueError:
            print("ERROR: Invalid offset input!")
            continue
        if 0 <= offset < len(KEY_BITS):
            print("Oracle result:", oracle.oracle(offset))
        else:
            print("ERROR: Invalid offset. Must be in range [0-{}]".format(len(KEY_BITS)-1))
    elif ch == "2":
        print("bye")
        break
    else:
        print("ERROR: Unknown command.")
```

## Writeup

### Intro

I will explain the attack simultaneously as I am explaining the server's code and code vulnerabilities, also the solver script at the end will explain itself but I put comments that remind of what I discuss in the writeup.

### Firstly

```python
P = 0xCD4A96D3B7FA7251A1BB765933FB676FCAE8C9026682E34F779122DFD66915BB
```

The first thing that made the attack possible, and if it was randomized, like:

```python
from Crypto.Util.number import getPrime
P = getPrime(512)
```
would make it impossible for me to guess what to send as the generator in `H(msg)` function as per line code `G = int(input("Before we start, give me the hashing generator: "))`. Before talking about `H(msg)` function, let's point out what it was used for, it is used in `keygen()` function to "encrypt" every tuple in `sk` and save it in `pk` as per the line code `pk = [(H(s[0]), H(s[1])) for s in sk]`.

### Secondly

Keeping that in mind, `H(msg)` function consists of three components to run a mathematical equation, one of which is a critical input `G` or the "generator" in `pow(G, msg, P)` received from user (me) , that is the second thing that made the attack possible.

Because `G` is set to a loose condition `1 < G < P` , it allows me to send a bad generator `G` , you see a generator must be a primitive root to the modulus `P` so it has an order of `P-1` and that would be a proper condition for `G` and make it secure (or at least harder for the attacker in this context), however I sent `P-1` as the generator which is not a primitive root modulo `P` and worse it has a specific order which is in mathematical form:

for a prime number $$P$$, $$G = P - 1$$ and $$0 < x$$:

$$G^x \pmod P = 1 \text{ or } P - 1$$


- whether the output is $$1$$ or $$P-1$$ depends on whether x is odd or even but it doesn't make a difference to the attack.
- $$x$$ is `msg` in `H(msg)` function.

making the output a very small set of {1, P-1} that represents the encrypted `sk` or `pk`. In other words, every number in every tuple (n1, n2) in `pk` equals to either `1` or `P-1`, it looks something like this: [(1,P-1),(1,1)...]. It's true that I don't have `sk`, but the thing is I don't need it thanks to `oracle(self, i)` function.

### Thirdly

The `oracle(self, i)` function, simply leaks the `KEY` bits by its logic. In line `ret = secrets.randbelow(2**N) if KEY_BITS[i] == 0 else PK[i % len(PK)][secrets.randbelow(2)]` it takes an offset from user and returns a *number* based on the offset's bit value (0 or 1) in `KEY`. It will return a random *number* as per  `randbelow(2**N)`, when the bit is equal to 0, otherwise it returns an integer of a tuple (n1, n2) in `pk` list by mapping the offset to the first index and then picks randomly between {0,1} as the second index as in the code line `PK[i % len(PK)][secrets.randbelow(2)]` in `oracle(self, i)` function, and the *number* returned - as mentioned before - is a predicted value in {1, P-1}.

Lastly, the possibility that `secrets.randbelow(2**N) if KEY_BITS[i] == 0` returns an integer in {1, P-1} is really low (probability = 2/2^N, N=256 in code line `N = sha256().digest_size * 8`), so we can **distinguish** between the bits simply just like that.

Note: Having put together all the points, in short the bits are distinguishable because of the difference between $$2^{256}$$ and $$P-1^x \pmod P$$, and it would have made it more difficult if any of the factors previously discussed were absent.

### Solver Script

Applying what I explained above in the following code with clarifying comments:

```python
from pwn import *
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad

P = 0xCD4A96D3B7FA7251A1BB765933FB676FCAE8C9026682E34F779122DFD66915BB
N = 256  # sha256().digest_size * 8

r = remote('154.57.164.62', 31519, level='debug')

r.recvuntil(b'Here is something for you:\n')
ct_hex = r.recvline().decode().strip()

r.sendlineafter(b'Before we start, give me the hashing generator: ', str(P - 1).encode())  # G = P-1

key = []  # key bits will be leaked from the server's "oracle" function and saved here.
for i in range(N):
    r.sendlineafter(b'> ', b'1')
    r.sendlineafter(b'Enter offset: ', str(i).encode())  # ask for every offset one by one via for loop.
    r.recvuntil(b'Oracle result: ')
    bit_result = int(r.recvline().strip())
    key.append(1 if bit_result in (1, P - 1) else 0)  # distinguish between every result. bit is 1 if the result was in {1, P-1} and bit is 0 otherwise.

r.sendlineafter(b'> ', b'2')  # exit
r.close()

print(f"key bits: {key}, len: {len(key)}, flag ct: {ct_hex}")

key_str = ''.join(str(b) for b in key)
key_int = int(key_str, 2)
KEY = key_int.to_bytes(32, byteorder='big')

ct = bytes.fromhex(ct_hex)
cipher = AES.new(KEY, AES.MODE_ECB)  # use the key to make the cipher and decrypt the flag using AES ECB mode.

try:
    flag = unpad(cipher.decrypt(ct), 16)
    print(flag)
except ValueError as e:
    print("Padding check failed, KEY likely wrong:", e)
    print("Raw decrypt:", cipher.decrypt(ct))
```

The virtual machine which I ran this on had a bit of a problem and was reset, but fortunately I captured the output from my phone.

<video controls autoplay loop muted playsinline style="max-width: 100%; height: auto;">
  <source src="/assets/videos/ctf/false_witness_writeup_solver_output.mp4" type="video/mp4">
</video>

However I ran it again in the "Cyber Apocalypse CTF 2026: The Salt Crown - After Party":

![screenshot](/assets/images/ctf/false_witness_writeup_screenshot.png)

the flag: `HTB{__l34k1ng_b1ts_0n3_by_0n3__}`

That's all, Thank you for reading!
