# Video Notes: Make your PC 95% HARDER to hack in 11 minutes

Source video: https://www.youtube.com/watch?v=2RkIHWygEVM

## Scope

This document is based on the transcript excerpt provided in chat. It is not a full transcript of the video.

## Executive Summary

The speaker's main argument is simple: default Windows security is not enough on its own. The video recommends a layered hardening approach that starts below the operating system, tightens Windows security controls, reduces network exposure, blocks common physical attack paths, hardens the browser, and limits account privileges.

The tone is opinionated and sometimes exaggerated, but the structure is coherent. The advice is mostly aimed at a Windows user who wants stronger local hardening without replacing the machine or changing operating systems.

## Audience and Framing

This advice is mainly for a personal Windows machine where the user is willing to trade some convenience for tighter security. It is not written like an enterprise baseline, and it is not a beginner-friendly walkthrough. It is closer to an enthusiast hardening checklist with strong opinions attached.

That matters because some of the recommendations are low-risk and broadly useful, while others add real friction and should be tested before being adopted as a default.

## Main Thesis

The video frames security as a stack:

1. Firmware and boot security come first.
2. Windows exploit mitigations and Defender hardening come second.
3. Network and outbound controls come next.
4. Physical access attacks are treated as real and practical.
5. Browser risk is treated as the main delivery path for threats.
6. Identity and privilege separation are treated as the final containment layer.

## Key Recommendations

### 1. Harden the firmware layer

The speaker recommends:

- Set BIOS/UEFI passwords.
- Enable Secure Boot.
- Enable kernel DMA protection when available.

Reasoning:

- A firmware password makes boot-order abuse harder.
- Secure Boot raises the bar for bootkits.
- DMA protection reduces the risk from malicious Thunderbolt or USB-C devices that can access memory directly.

### 2. Tighten Windows exploit protection

The speaker calls out:

- Windows Security
- App and Browser Control
- Exploit Protection
- Control Flow Guard

Reasoning:

- Exploit mitigations are meant to make memory-corruption attacks and execution redirection harder.
- The argument is that these features should be reviewed and explicitly enabled rather than left on default assumptions.

### 3. Harden Defender with aggressive rules

The video recommends using a Defender configuration tool to enable stronger rules, especially:

- Attack Surface Reduction (ASR) rules
- Block Office applications from creating child processes
- Block obfuscated scripts
- Block executable content from email

Reasoning:

- The speaker treats these as high-value controls because they target common malware behavior rather than specific malware families.
- The Office child-process rule is presented as a major ransomware reduction measure.

### 4. Reduce unnecessary Windows services

The speaker argues for disabling:

- Telemetry
- Remote Registry
- Print Spooler
- Other unnecessary background services

Reasoning:

- Less running code means less attack surface.
- Services that are not needed should not remain exposed by default.

### 5. Enable virtualization-based security

The video recommends:

- Device Security
- Core Isolation
- Memory integrity
- Microsoft vulnerable driver block list

Reasoning:

- Virtualization-based security isolates sensitive execution paths.
- The vulnerable driver block list is intended to stop "bring your own vulnerable driver" abuse.

### 6. Harden DNS and outbound network behavior

The speaker recommends:

- Switching DNS to Quad9
- Enabling DNS over HTTPS
- Using SimpleWall for outbound filtering

Reasoning:

- Quad9 is positioned as a threat-focused resolver.
- DNS over HTTPS hides DNS lookups from local intermediaries and the ISP.
- Outbound filtering is treated as a missing layer in the default Windows firewall model.

### 7. Take physical attacks seriously

The video emphasizes:

- USB-based attack devices
- Public charging risks
- Device installation restrictions in Group Policy
- Use of USB data blockers

Reasoning:

- Brief unattended physical access is treated as enough time for compromise.
- The proposed defense is to prevent new device installation unless intentionally allowed.

### 8. Treat the browser as the main threat surface

The speaker recommends:

- Using a hardened browser setup
- Preferring Brave or hardened Firefox
- Using NoScript for high-risk browsing
- Clearing cookies on exit

Reasoning:

- The browser is framed as the most common delivery path for web-based malware and session theft.
- JavaScript is treated as the main execution path for browser exploitation.

### 9. Separate identity from privilege

The video recommends:

- Using a password manager such as Bitwarden
- Generating long random passwords
- Using a standard user account instead of an administrator account

Reasoning:

- Password reuse and weak passwords remain a major identity problem.
- Running daily work as a standard user limits the blast radius of malware.

## Practical Priority Order

If the goal is to turn this into an actionable checklist, the most sensible order is:

1. Set firmware password and enable Secure Boot.
2. Enable Core Isolation and the vulnerable driver block list.
3. Review Exploit Protection and Defender hardening.
4. Apply ASR rules carefully and test business-critical workflows.
5. Move daily work to a standard user account.
6. Switch DNS and enable DNS over HTTPS.
7. Add outbound filtering if you are willing to manage prompts and rules.
8. Lock down device installation and avoid public USB data paths.
9. Harden the browser and reduce cookie persistence.

## Highest-Value Takeaways

If this video is reduced to the controls with the best security-to-friction ratio, the strongest takeaways are:

- Use a password manager and unique long passwords.
- Stop using an administrator account for daily work.
- Enable Secure Boot if the system supports it cleanly.
- Turn on Core Isolation and related driver protections where hardware support is stable.
- Review Defender and ASR settings instead of assuming defaults are enough.
- Treat browser sessions, physical access, and USB devices as real attack surfaces.

These are the parts of the video that remain useful even if some of the rhetoric is stripped away.

## High-Friction Recommendations

These recommendations can improve security, but they come with enough operational cost that they should be treated as deliberate choices rather than universal defaults:

- Aggressive ASR rules
- Outbound application firewalls
- Device installation restrictions
- NoScript-style default script blocking
- Disabling a wide range of Windows services without a validated dependency check

The common pattern is that these controls can be effective, but they can also break normal workflows in ways the video does not fully account for.

## What the Video Gets Right

- It emphasizes layered defense instead of relying on antivirus alone.
- It treats physical access as a real threat, not a niche scenario.
- It pushes least privilege, which is one of the highest-value controls mentioned.
- It focuses on behavior-based blocking such as ASR rules and exploit mitigations.
- It correctly treats browser sessions and cookies as valuable targets.

## Caveats and Claims to Verify

Some parts of the excerpt are strong advice. Some parts are opinionated or need validation before broad rollout.

### Strong advice

- Use a password manager.
- Stop using an administrator account for daily work.
- Enable Secure Boot if your environment supports it.
- Review Core Isolation and driver protections.
- Prefer fewer running services and less exposed functionality.

### Advice that needs testing before rollout

- Aggressive ASR rules can break legitimate workflows.
- Device installation restrictions can interfere with normal hardware use.
- Script blocking can make many sites unusable.
- Outbound firewalls increase security, but they also add operational friction.

### Claims that are overstated or technically loose

- The "cold boot attack" explanation is imprecise. The transcript blends physical boot-path abuse with cold-boot-style memory attacks.
- DNS over HTTPS improves privacy for DNS lookups, but it does not make browsing activity generally invisible to the ISP.
- The claim that enabling a specific ASR rule kills "90%" of macro-based ransomware is a rhetorical claim, not something established in the transcript.
- The DMA section appears partly mistranscribed. The line about a malicious implant "can't use DMA" conflicts with the point being made and likely should read "can use DMA."
- BIOS or UEFI passwords help, but they are not a complete answer to physical compromise if the attacker has prolonged access.

### Transcript items that look mistranscribed

- `GPI.msc` is almost certainly `gpedit.msc`.
- `Simple Wool` is almost certainly `SimpleWall`.
- `BBS` is likely `VBS`, meaning virtualization-based security.
- `tele` likely means telemetry.
- `cross-ite scripting` is clearly `cross-site scripting`.
- `hardearned Firefox` likely means a hardened Firefox configuration.
- `lease privilege` should be `least privilege`.

## Notable Quote

> "The only true secure computer is one that's turned off inside a safe at the bottom of the ocean."

This is the framing device for the whole clip: absolute security is unrealistic, so the real goal is to raise the cost of attack through layers.

## Bottom Line

The video is strongest when it argues for layered defense, least privilege, browser hardening, and physical-access awareness. It is weakest when it compresses technical nuance into punchy claims or presents high-friction controls as if they are free.

As a structured takeaway, this is a useful hardening checklist with an aggressive tone, not a fully reliable technical authority on every detail.

## Appendix: Transcript Excerpt

### Timestamped Transcript

- [00:00:05] The only true secure computer is one
- [00:00:08] that's turned off inside a safe at the
- [00:00:10] bottom of the ocean. But since you
- [00:00:12] probably want to, you know, use your
- [00:00:14] computer, then we're going to build the
- [00:00:16] next best thing avoiding the usual
- [00:00:18] suspects.
- [00:00:19] So, first thing on the list, anti
- [00:00:21] viruses. Two videos ago, which is like
- [00:00:24] 50 years in the past, I said some things
- [00:00:26] about Windows Defender that started a
- [00:00:28] literal war zone in the comment section
- [00:00:29] for some reason. But like I said in the
- [00:00:31] TLDDR of that video, Windows Defender
- [00:00:33] isn't bad. It's just not very good if
- [00:00:35] you don't supplement it with functioning
- [00:00:37] brain cells and the things that I'll
- [00:00:38] tell you right now. So, all right,
- [00:00:40] security doesn't start in Windows, it
- [00:00:42] starts in the UEFI. The golden rule here
- [00:00:44] is that if your BIOS is open, your PC is
- [00:00:47] just a toy. So the first step is to set
- [00:00:49] a password for each of them because the
- [00:00:50] cold boot attack is real. That is if
- [00:00:53] someone has physical access to your
- [00:00:54] machine for 60 seconds because they can
- [00:00:57] boot a specialized Linux dro from the
- [00:00:59] USB and dump your RAM or bypass your
- [00:01:01] local login. But the good news, however,
- [00:01:03] is that if you have a BIOS password, it
- [00:01:05] locks the boot order, killing the hijack
- [00:01:07] before it even starts. Next, enable
- [00:01:09] secure boot. I know the Linux community
- [00:01:11] is going to hate it, but if you're in a
- [00:01:13] Windows environment, then this is your
- [00:01:14] first line of defense against boot kits.
- [00:01:17] This is of course assuming that your
- [00:01:18] main OS is Windows, which if it is,
- [00:01:20] first of all, what are you doing? But if
- [00:01:22] you're based and use Linux, then I still
- [00:01:24] recommend it unless you're like a power
- [00:01:26] user or something. Now, we look for
- [00:01:28] kernel DMA protection. DMA is a feature
- [00:01:30] that allows hardware like Thunderbolt or
- [00:01:33] USBC devices to talk directly to your
- [00:01:35] RAM without involving your CPU. Now,
- [00:01:38] don't get me wrong, it is a massive
- [00:01:40] performance boost, but it can also be a
- [00:01:42] security nightmare. For example, a
- [00:01:44] malicious hardware implant can't use DMA
- [00:01:46] to read your encryption key straight out
- [00:01:48] of your memory, and that's pretty bad.
- [00:01:50] So, enabling kernel DMA protection
- [00:01:52] ensures that your OS is the one who
- [00:01:54] manages these requests, creating a
- [00:01:56] logical barrier between your ports and
- [00:01:58] your secrets. And if your motherboard is
- [00:02:00] from like 2020 or later, and this is
- [00:02:02] off, you're leaving a physical back door
- [00:02:04] wide open for a $20 hardware exploit.
- [00:02:07] So, I would advise to leave it on. Go to
- [00:02:08] Windows Security, App and Browser
- [00:02:10] Control, and Exploit Protection. Don't
- [00:02:13] just look at it, tweak it. Be absolutely
- [00:02:15] sure that control flow guard is on
- [00:02:18] because this basically performs checks
- [00:02:20] on indirect call instructions to prevent
- [00:02:22] like jump oriented programming or JOP
- [00:02:25] attack.
- [00:02:26] >> English mother.
- [00:02:26] >> Let me just stop reading. It stops a
- [00:02:28] hacker from redirecting your programs
- [00:02:30] flow into their own malicious code. And
- [00:02:32] it's the difference between a door
- [00:02:34] that's shut and a door that's bolted.
- [00:02:36] Here's one of the reasons I hate Windows
- [00:02:38] so much. Basically, Microsoft hides the
- [00:02:40] most aggressive security features behind
- [00:02:42] PowerShell commands because they're
- [00:02:43] afraid of support tickets. But guess
- [00:02:45] what? We are not.
- [00:02:48] Go to GitHub right now and get configure
- [00:02:50] defender and set it to hide. This
- [00:02:52] enables ASR attack surface reduction
- [00:02:55] rules. This is crucial because ASR
- [00:02:58] allows you to block specific behaviors
- [00:03:00] that almost exclusively are used for
- [00:03:02] malware. For example, we have block
- [00:03:04] office applications from creating child
- [00:03:06] processes because there is zero reasons
- [00:03:08] for Microsoft Word to even launch a cmd
- [00:03:11] window or PowerShell script. And by
- [00:03:13] enabling this, you kill 90% of
- [00:03:15] macrobased ransomware instantly. You
- [00:03:18] also want to enable block obuscated
- [00:03:20] scripts and block executable content
- [00:03:22] from email.
- [00:03:24] Oh my god, I run out of air. Block
- [00:03:26] executable content from email client.
- [00:03:28] So, you're basically telling your OS,
- [00:03:30] "Hey, if you by any chance encounter
- [00:03:33] something that looks like a dog and
- [00:03:35] quacks like a hacker, then kill it
- [00:03:37] before it speaks."
- [00:03:39] I have a personal ideology that states
- [00:03:41] that if a service doesn't need to run,
- [00:03:43] then it shouldn't exist. Use any of
- [00:03:45] these tools to disable tele and
- [00:03:47] unnecessary background services like
- [00:03:49] remote registry or print spooler. Like,
- [00:03:52] just why? Now, we get into the heavy
- [00:03:55] stuff. BBS or virtualization based
- [00:03:57] security is the pro tier. Windows 10 or
- [00:04:00] 11 can use the CPU's hardware
- [00:04:02] virtualization, the same thing used to
- [00:04:04] run virtual machines to create a secure
- [00:04:06] region of memory that is completely from
- [00:04:09] the OS. Just go to Windows security
- [00:04:11] device security and core isolation. This
- [00:04:14] ensures that every single driver trying
- [00:04:16] to run your kernel is verified and
- [00:04:18] isolated in a bubble first. And have in
- [00:04:20] mind that enabling this also takes away
- [00:04:22] some performance, but believe me, it's
- [00:04:25] worth it. Also, I almost forgot, enable
- [00:04:27] Microsoft vulnerable drivers block list
- [00:04:29] because hackers love using bring your
- [00:04:31] own vulnerable driver attacks.
- [00:04:33] Basically, they take a legitimate but
- [00:04:35] old and buggy driver from a puritable
- [00:04:37] company and install it into your system.
- [00:04:39] This block list is a database of those
- [00:04:41] known bad good drivers. So, keep it
- [00:04:43] updated. And in case you're liking this
- [00:04:45] video, please subscribe. I have a lot of
- [00:04:47] crazy video ideas for this 26. I
- [00:04:49] wouldn't want you to miss. So, your PC
- [00:04:51] is now hardened, but unfortunately, your
- [00:04:53] network is still a public park. Most
- [00:04:56] people don't realize that every time you
- [00:04:57] visit a website, your PC sends a plain
- [00:05:00] text request to your ISP's DNS. And your
- [00:05:02] ISP knows every site you visit. And more
- [00:05:05] importantly, those requests can be
- [00:05:07] intercepted or spoofed by anyone on your
- [00:05:10] local network. This is how DNS hijacking
- [00:05:13] works. So step one, if security is your
- [00:05:16] main concern, then change your DNS to
- [00:05:18] Quad 9 because they are basically a
- [00:05:20] nonprofit organization that specializes
- [00:05:22] in thread security. And every time you
- [00:05:24] try to connect to a domain, they check
- [00:05:26] it against a global database of malware
- [00:05:28] command and control servers. If the
- [00:05:30] domain is malicious, then Quad9 simply
- [00:05:32] gaslights your computer and tells them
- [00:05:34] that that address doesn't exist. Next,
- [00:05:36] enable DNS over HTTPS. Go to Windows
- [00:05:39] settings, network and internet, Ethernet
- [00:05:41] and Wi-Fi, and DNS settings. Set it to
- [00:05:44] manual and toggle the DNS over HTTPS to
- [00:05:47] on. Now your DNS requests are wrapped on
- [00:05:50] TLS encryption. Your ISP can no longer
- [00:05:52] see what domains you're looking up and
- [00:05:54] hackers on your Wi-Fi cannot poison your
- [00:05:56] DNS.
- [00:05:58] We all know that Windows firewall is
- [00:06:00] great at blocking incoming connections,
- [00:06:02] but it's a little bit of a snitch when
- [00:06:04] it comes to outgoing ones because for
- [00:06:06] some reason it lets almost everything
- [00:06:08] talk to the internet and that's just
- [00:06:09] tragic. So just install Simple Wool.
- [00:06:12] It's an open- source front end for the
- [00:06:14] Windows filtering platforms. And with
- [00:06:16] Simple Wool, I found it really
- [00:06:18] convenient that nothing happens until
- [00:06:20] you say yes. Now we come to my favorite
- [00:06:22] part of cyber security, physical stuff.
- [00:06:24] All right, let's say you're at a coffee
- [00:06:26] shop, right? and you go to the bathroom
- [00:06:27] and leave your laptop open for 60
- [00:06:30] seconds. Well, first of all, shame on
- [00:06:31] you. And second of all, it takes less
- [00:06:33] than that for someone to just plug in a
- [00:06:35] rubber donkey and that's it. It's over.
- [00:06:37] Because a device like this can type
- [00:06:39] PowerShell commands at 1,000 words per
- [00:06:42] minute that downloads a remote access
- [00:06:43] Trojan, executes it, and hides in the
- [00:06:46] process. I mean, it's done. The fix I
- [00:06:48] like to implement for this is going into
- [00:06:50] GPI.msc
- [00:06:51] and navigate here. then enable this
- [00:06:53] option and it will practically just
- [00:06:55] freeze your IO. If a new device is
- [00:06:57] plugged, whether it be a keyboard, a
- [00:06:59] drive, or a hacker tool, Windows will
- [00:07:01] refuse to install the driver. You can
- [00:07:03] only disable this when you're
- [00:07:04] intentionally adding hardware. So, keep
- [00:07:06] that in mind. And please, I am begging
- [00:07:08] you. All the people that I see out there
- [00:07:10] using those public charging ports and
- [00:07:12] USB, I mean, just
- [00:07:14] >> stop it.
- [00:07:14] >> But if you really need to use them, I
- [00:07:16] mean, like pretty bad. Let's say your
- [00:07:18] non-existent wife texted you, your
- [00:07:20] village is getting attacked, you want a
- [00:07:21] brand new car, you need to call 9/11 or
- [00:07:24] any of those things. You can just buy
- [00:07:25] USB condom.
- [00:07:28] I wish I was joking, but I'm not. These
- [00:07:30] things exist and that are lifesaver and
- [00:07:32] not because of reason that you think.
- [00:07:34] No, that that does not go in there. They
- [00:07:37] prevent data transfer so you can just
- [00:07:38] plug it and charge your phone normally
- [00:07:40] without worrying about getting your
- [00:07:41] stuff stolen or something. I don't know
- [00:07:43] what the script was again. 90% of your
- [00:07:46] threats are delivered via the browser.
- [00:07:48] Using vanilla Chrome is like walking
- [00:07:50] through a biological weapon lab without
- [00:07:52] a suit. You can use whatever browser you
- [00:07:54] think is the best. I find myself using
- [00:07:56] between Brave and hardearned Firefox,
- [00:07:59] but that's just up to you. And a pro
- [00:08:00] tip, JavaScript is the root of all evil
- [00:08:03] when we talk about web exploitation.
- [00:08:05] Almost every browserbased exploit relies
- [00:08:07] on JS to run on its payload. So for
- [00:08:10] high-risk browsing, use no script. It
- [00:08:12] blocks all scripts by default. So yeah,
- [00:08:15] it will break most modern websites, but
- [00:08:17] that's the point. You allow scripts one
- [00:08:20] by one only on the sites you trust. It's
- [00:08:22] tedious, yeah, but it makes you immune
- [00:08:24] to drive by downloads and cross-ite
- [00:08:27] scripting. Finally, just clear your
- [00:08:29] cookies on exit. Stale session cookies
- [00:08:31] are a gold mine for hackers. If they
- [00:08:33] steal your session token, they can
- [00:08:35] bypass your password and 2FA.
- [00:08:38] Let's talk about the identity failure
- [00:08:40] point. If your password is your dog's
- [00:08:41] name, followed by one through three. I
- [00:08:43] don't mean no offense, but my personal
- [00:08:46] recommendation would be using Bit
- [00:08:48] Warden. I mean, it's just what I use.
- [00:08:50] It's open source, it's free, and it's
- [00:08:52] secure. You can generate a 30 character
- [00:08:54] random string. But here's the move that
- [00:08:57] most people miss. You got to stop using
- [00:08:59] an administrator account. If you're
- [00:09:01] admin, the malware is admin. But if
- [00:09:03] you're standard, then the malware is
- [00:09:04] standard as well, and it hits a UAC
- [00:09:06] prompt, it dies. In my opinion, this
- [00:09:08] principle of lease privilege is the
- [00:09:10] single most effective way to stop a
