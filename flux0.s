.intel_syntax noprefix
.equ SRC_MAX, 65536
.equ MSG_MAX, 65536
.equ O_RDONLY, 0
.equ O_WRONLY, 1
.equ O_CREAT, 64
.equ O_TRUNC, 512

.section .rodata
usage_msg: .asciz "usage: ./flux0 <input.flux> <output.s>\n"
parse_msg: .asciz "flux0: parse error\n"
io_msg: .asciz "flux0: io error\n"

asm_p1: .asciz ".section .rodata\nmsg:\n  .byte "
asm_p2: .asciz "\n\n.section .text\n.global _start\n_start:\n  mov $1, %rax\n  mov $1, %rdi\n  lea msg(%rip), %rsi\n  mov $"
asm_p3: .asciz ", %rdx\n  syscall\n  mov $60, %rax\n  mov $"
asm_p4: .asciz ", %rdi\n  syscall\n"
comma_sp: .asciz ", "
zero_ch: .asciz "0"
kw_done: .ascii "done"

.section .bss
.align 16
src_buf: .skip SRC_MAX
msg_buf: .skip MSG_MAX
num_buf: .skip 32

.section .text
.global _start

_start:
  mov rax, [rsp]
  cmp rax, 3
  je have_args
  mov rdi, 2
  lea rsi, [rip + usage_msg]
  call write_cstr
  mov rax, 60
  mov rdi, 1
  syscall

have_args:
  mov r14, [rsp + 16]
  mov r15, [rsp + 24]
  lea rbx, [rip + msg_buf]

  mov rax, 2
  mov rdi, r14
  mov rsi, O_RDONLY
  xor rdx, rdx
  syscall
  cmp rax, 0
  jl io_error
  mov r12, rax

  mov rax, 0
  mov rdi, r12
  lea rsi, [rip + src_buf]
  mov rdx, SRC_MAX
  syscall
  cmp rax, 0
  jle io_error_close_in
  mov r13, rax

  mov rax, 3
  mov rdi, r12
  syscall

  lea rsi, [rip + src_buf]
  mov rcx, r13
find_open_quote:
  test rcx, rcx
  je parse_error
  mov al, byte ptr [rsi]
  cmp al, '"'
  je found_open_quote
  inc rsi
  dec rcx
  jmp find_open_quote

found_open_quote:
  inc rsi
  dec rcx
  xor r8, r8
parse_str_loop:
  cmp r8, MSG_MAX
  jae parse_error
  test rcx, rcx
  je parse_error
  mov al, byte ptr [rsi]
  cmp al, '"'
  je done_parse_str
  cmp al, '\\'
  je parse_escape
store_char:
  mov byte ptr [rbx + r8], al
  inc r8
  inc rsi
  dec rcx
  jmp parse_str_loop

parse_escape:
  inc rsi
  dec rcx
  test rcx, rcx
  je parse_error
  mov al, byte ptr [rsi]
  cmp al, 'n'
  jne store_escaped_raw
  mov al, 10
  jmp store_char

store_escaped_raw:
  jmp store_char

done_parse_str:
  mov r9, r8

  lea rsi, [rip + src_buf]
  mov rcx, r13
  xor r10, r10
find_return_loop:
  cmp rcx, 4
  jb finish_parse
  mov al, byte ptr [rsi]
  cmp al, byte ptr [rip + kw_done]
  jne next_return_scan
  mov al, byte ptr [rsi + 1]
  cmp al, byte ptr [rip + kw_done + 1]
  jne next_return_scan
  mov al, byte ptr [rsi + 2]
  cmp al, byte ptr [rip + kw_done + 2]
  jne next_return_scan
  mov al, byte ptr [rsi + 3]
  jne next_return_scan
  add rsi, 4
skip_ws:
  mov al, byte ptr [rsi]
  cmp al, ' '
  je ws_step
  cmp al, 9
  je ws_step
  cmp al, 10
  je ws_step
  cmp al, 13
  je ws_step
  jmp parse_digits
ws_step:
  inc rsi
  jmp skip_ws

parse_digits:
  xor r10, r10
digit_loop:
  movzx rax, byte ptr [rsi]
  cmp al, '0'
  jb finish_parse
  cmp al, '9'
  ja finish_parse
  imul r10, r10, 10
  sub rax, '0'
  add r10, rax
  inc rsi
  jmp digit_loop

next_return_scan:
  inc rsi
  dec rcx
  jmp find_return_loop

finish_parse:
  mov rax, 2
  mov rdi, r15
  mov rsi, O_WRONLY | O_CREAT | O_TRUNC
  mov rdx, 420
  syscall
  cmp rax, 0
  jl io_error
  mov r12, rax

  mov rdi, r12
  lea rsi, [rip + asm_p1]
  call write_cstr

  cmp r9, 0
  jne bytes_loop_start
  mov rdi, r12
  lea rsi, [rip + zero_ch]
  call write_cstr
  jmp bytes_done

bytes_loop_start:
  xor r8, r8
bytes_loop:
  movzx rax, byte ptr [rbx + r8]
  mov rdi, r12
  call write_u64
  inc r8
  cmp r8, r9
  je bytes_done
  mov rdi, r12
  lea rsi, [rip + comma_sp]
  call write_cstr
  jmp bytes_loop

bytes_done:
  mov rdi, r12
  lea rsi, [rip + asm_p2]
  call write_cstr

  mov rdi, r12
  mov rax, r9
  call write_u64

  mov rdi, r12
  lea rsi, [rip + asm_p3]
  call write_cstr

  mov rdi, r12
  mov rax, r10
  call write_u64

  mov rdi, r12
  lea rsi, [rip + asm_p4]
  call write_cstr

  mov rax, 3
  mov rdi, r12
  syscall

  mov rax, 60
  xor rdi, rdi
  syscall

parse_error:
  mov rdi, 2
  lea rsi, [rip + parse_msg]
  call write_cstr
  mov rax, 60
  mov rdi, 1
  syscall

io_error_close_in:
  mov rax, 3
  mov rdi, r12
  syscall
io_error:
  mov rdi, 2
  lea rsi, [rip + io_msg]
  call write_cstr
  mov rax, 60
  mov rdi, 1
  syscall

write_cstr:
  push rdi
  mov rdx, rsi
wc_len:
  cmp byte ptr [rdx], 0
  je wc_write
  inc rdx
  jmp wc_len
wc_write:
  sub rdx, rsi
  mov rax, 1
  pop rdi
  syscall
  ret

write_u64:
  push rbx
  push r8
  push r9
  mov rbx, 10
  lea r8, [rip + num_buf + 31]
  mov r9, r8
  cmp rax, 0
  jne wu_loop
  mov byte ptr [r8], '0'
  mov rsi, r8
  mov rdx, 1
  mov rax, 1
  syscall
  jmp wu_done
wu_loop:
  xor rdx, rdx
  div rbx
  add dl, '0'
  mov byte ptr [r8], dl
  dec r8
  test rax, rax
  jne wu_loop
  lea rsi, [r8 + 1]
  mov rdx, r9
  sub rdx, r8
  mov rax, 1
  syscall
wu_done:
  pop r9
  pop r8
  pop rbx
  ret
