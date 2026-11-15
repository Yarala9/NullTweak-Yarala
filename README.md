# NullTweak-Yarala
Basic vibecoded tweaking app, do whatever u want with it, Use at your own risk. This tool changes system settings, services, and removes apps. Make a restore point first. I’m not responsible for any issues on your system.
irm https://get.activated.win | iex Then Click 1 HWID
Run the Code below in Powershell (Doesn't Have to be as Administrator)

```$f="$env:TEMP\NullTweak.ps1"; irm https://raw.githubusercontent.com/Yarala9/NullTweak-Yarala/main/NullTweak.ps1 -OutFile $f; Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$f```
