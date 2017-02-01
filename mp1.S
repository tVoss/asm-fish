
.data					# section declaration

        # Useful offset constants for accessing members of a
        # struct mp1_blink_struct structure
        LOCATION   = 0
        ON_CHAR    = 2
        OFF_CHAR   = 3
        ON_LENGTH  = 4
        OFF_LENGTH = 6
        COUNTDOWN  = 8
        STATUS     = 10
        NEXT       = 12

        STRUCT_SIZE = 16

# Pointer to head of list (initialized to NULL)
mp1_list_head:
        .long   0

.text					# section declaration

# Export the function symbol names

.global mp1_rtc_tasklet
.global mp1_ioctl

# void mp1_poke(void);
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX
mp1_poke:

	movl    vmem_base_addr(,1),%edx
	movb    %cl,(%edx,%eax,1)
	ret

mp1_rtc_tasklet:
    pushl %ebp                      # Create stack frame
    movl %esp, %ebp

    pushl %ebx                      # Save registers
    pushl %esi

    movl mp1_list_head, %ebx        # Set ebx to head of the list

    walk:
        testl %ebx, %ebx                # If pointer is null break out of loop
        jz end_walk
        sub $1, COUNTDOWN(%ebx)        # Decrement counter
        jnz no_poke
            mov STATUS(%ebx), %dx         # Grab status and put it in edx
            movb ON_CHAR(%ebx, %edx), %cl   # Swaps char and puts it in cl
            mov LOCATION(%ebx), %ax       # Moves location to eax
            call mp1_poke
            mov ON_LENGTH(%ebx, %edx, 2), %ax
            mov %ax, COUNTDOWN(%ebx)   # Puts appropriate length in place
            xor $1, STATUS(%ebx)           # Flip status
        no_poke:
        movl NEXT(%ebx), %ebx       # Reassign next pointer
        jmp walk
    end_walk:

    popl %esi
    popl %ebx                   # Restore registers

    leave
	ret

mp1_ioctl:
	ret

mp1_ioctl_add:
	ret

mp1_ioctl_remove:
	ret

mp1_ioctl_find:
	ret

mp1_ioctl_sync:
	ret

.end
