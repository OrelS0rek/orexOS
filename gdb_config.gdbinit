# =============================================================
# OREX-OS STABLE DEBUGGER (MacOS Final Version)
# =============================================================

set confirm off
set pagination off
set prompt \033[31mreal-mode-gdb$ \033[0m
set disassembly-flavor intel

# 1. Connection Logic
set architecture i386:x86-64
target remote localhost:1234
set architecture i8086

# 2. Breakpoint
break *0x7c00

# 3. The Stable Dashboard (Manual Refresh)
# We use a single command 'd' to show everything so GDB doesn't hang.
define d
  printf "\033[1;33m--- REGS ---\033[0m\n"
  info registers ax bx cx dx si di bp sp cs ds es ss eip
  printf "\033[1;32m--- CODE ---\033[0m\n"
  # This shows the next 5 instructions at the current instruction pointer
  x/5i $pc
  printf "\033[1;35m--- STACK ---\033[0m\n"
  x/4xw $sp
end

# 4. Step Shortcut
define s
  stepi
  d
end

# 5. Continue Shortcut
define c
  continue
end

# Start
printf "\033[1;32mConnected! Use 's' to step and 'd' to see the dashboard.\n\033[0m"
continue