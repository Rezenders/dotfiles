# Run by kitty's `geninclude`: prints the include line for this machine's host-specific config.
# 'beast' is the personal machine; every other host gets the work config.
import socket

machine = "beast" if socket.gethostname() == "beast" else "work"
print(f"include hosts/{machine}.conf")
