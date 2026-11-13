# Xbox-Gameinput-Wipe

**Xbox-Gameinput-Wipe**

A windows batch / powershell script that force-wipes all Microsoft Xbox background services, GameBar overlays, and the Microsoft GameInput driver framework; locking the file systems so that they cannot restore themselves after a windows update or restart.
Microsoft's GameInput service and GameDVR overlays notoriously clash with NVIDIA video drivers (NVENC hardware encoder), making it directly responsible complete GPU hangs.
Unfortunately, Windows decides it was good idea to make it so they forcefully reinstall themselves onto your computer silently, after the user uninstalls it for whatever reason.

**Set-up and Use**
- Install the .bat
- Run the .bat (Admin privileges required)
- Reboot your PC.

(The script invokes Windows PowerShell 5.1 which ships natively with windows 10 & 11, so no prerequisite installations are required.)

**How It Works**

The script leverages NTFS ownership takeover combined with DACL manipulation via native Windows command line utilities. (takeown.exe & icacls.exe), operating under an elevated administrator token.

1. UAC Token Elevation
2. Breaking TrustedInstaller protection (takeown.exe)
3. Renaming System Binaries via Renaming (icacls.exe + Rename-Item)
4. Directory Replacement / Explicit SID Write-Locking (icacls.exe /deny)

Because Windows Kernel evaluates explicit >Deny ACEs before any >Allow entries, any subsequent installer or update service running as >SYSTEM immediately hits an Access Denied error when attempting to write files into those folders. 

**Why?**

I run a 5070 on a older Z390 Chipset (2018). Though PCIe is backwards compatable, and a 5070 will run on a older Z390 board with PCIe 3.0, there happens to be some handshake issue between the NIVIDA drivers and Xbox/Windows between a card using PCIe 5.0 and a PCIe 3.0 board.
I noticed through reliability monitor, that the time of crashes corresponded one-to-one with a reinstallation of XboxGamingServices, GameDVR(overlays), or Gameinput.
Removing both fixed my issue.

**DISCLAIMER: RUN AT YOUR OWN RISK.**

I built this tool for personal use, and since I am the only real-world tester, YOU may run into unforeseen edge cases before I do. If you find a bug, please email me at peppereddd@gmail.com with the steps to reproduce the issue so I can test it and push a fix. 

AI Disclosure: 20%-30% of the end-product code was generated using AI. AI was used in the process only to troubleshoot and identify edge-cases and bugs in advance.
