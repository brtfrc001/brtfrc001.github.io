---
title: "attack chain - crafting payload: section injection"
categories: Research
tags: attack-chain craft-payload malware stealth
toc: true
mermaid: true
share: true
media_subpath: /assets/images/crafting_payload_section_injection
---

In this post, we'll embed a reverse shell binary as a new section in a benign executable, which is referred to as section injection and identified by MITRE ATT&CK as "Obfuscated Files or Information: Embedded Payloads - ID: T1027.009" a technique used in stealth tactic by adversaries in malware development.

### Part 1: Reverse shell

I made a reverse shell as an ELF binary using `msfvenom` command line tool and named it `shell.elf`.

![image.png](image%202.png)

### Part 2: Inject `shell.elf` into a legitimate binary

To do this first, I have to make a fake update executable.

```c
#include <stdio.h>
#include <unistd.h>

int main(void) {
    printf("Loading");
    fflush(stdout);

    for (int i = 0; i < 5; i++) {
        usleep(400000); // 0.4 seconds
        printf(".");
        fflush(stdout);
    }

    printf("\nUpdate complete.\n");
    return 0;
}
```

Compile with the flag `-no-pie` this prevents the PIE feature and insures constant or hardcoded entry point address, that is very important for injecting our malicious code into it later.

![image.png](image%203.png)

Running `update.elf` , it prints fake loading prompt.

![image.png](image%204.png)

As shown, the binary type is `EXEC (Executable file)` and not `DYN (Position-Independent Executable file)` as we intended.

![image.png](image%205.png)

To combine the two executable files into a single one, first I have to extract the raw binary from `shell.elf` , to do that I need two key information, the `main` address (entry point) which is where the program actually starts executing and the size of it.

To find them, I can view entry point using `readelf` , shown below the entry point is `0x400078` .

![image.png](image%206.png)

Next, finding the size of it using the reverse engineering tool `radare2` in the command line.

![image.png](image%207.png)

In the command line interface I execute `aaa` for initiating analysis and then `pdf@ entry0` to print disassembly of function `entry0` which is the main function, we notice that the first line address corresponds to what we saw in `readelf` command printed headers.

To calculate the size, we use start address (entry point) and end address, shown below the end of main address is `0x40010a` .

Then calculate : size = end - start

which equals 146 in decimal

![image.png](image%208.png)

Then extract raw binary from `shell.elf` to `shell.bin` using `dd` tool and the information we got.

![image.png](image%209.png)

This raw binary `shell.bin` will be embedded into `update.o` executable file.

To do this, we add it as a new section using `objcopy` command line tool and name the section `.inject`.

Some flags must be specified to execute the binary within `.inject`, being: `alloc,load,data,contents,code` .

![image.png](image%2010.png)

In the image above, the command reproduced `update.o` and it is now a relocatable object file, which means it is compiled but needs linking, simply by `gcc` command shown below.

![image.png](image%2011.png)

And now we have an executable object file named `update` , let’s view the section using `readelf` .

![image.png](image%2012.png)

We can see the magic byte of an ELF (Executable and Linking Format) at the start of hex dump of section, but it doesn't mean that our code being executed at runtime yet.
At the end we have successfully embedded a new section that has malicious code in a legitimate executable, and it's not flagged by detection engines because of this approach in crafting payload.
