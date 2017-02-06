
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

    xor %eax, %eax                  # Clear out eax
    xor %edx, %edx

    movl mp1_list_head, %ebx        # Set ebx to head of the list

    walk:
        testl %ebx, %ebx                # If pointer is null break out of loop
        jz end_walk
        sub $1, COUNTDOWN(%ebx)         # Decrement counter
        jnz no_poke
            xor %edx, %edx                  # Clear out edx
            movw STATUS(%ebx), %dx           # Grab status and put it in edx
            movb ON_CHAR(%ebx, %edx), %cl   # Swaps char and puts it in cl
            movw LOCATION(%ebx), %ax         # Moves location to eax
            pushl %edx
            call mp1_poke                   # edx gets clobbered
            popl %edx
            movw ON_LENGTH(%ebx, %edx, 2), %ax
            movw %ax, COUNTDOWN(%ebx)        # Puts appropriate length in place
            xor $1, STATUS(%ebx)            # Flip status
        no_poke:
        movl NEXT(%ebx), %ebx           # Reassign next pointer
        jmp walk
    end_walk:

    popl %esi
    popl %ebx                   # Restore registers

    leave
	ret

mp1_ioctl:
    movl 8(%esp), %eax          # Get command number
    cmp $3, %eax                # Check if number is greater than 3
    ja error                    # If it is jump to error
    jmp *ioctl_table(, %eax, 4) # Otherwise jump to functionality
    error:
    movl $-1, %eax               # Return 0
	ret

mp1_ioctl_add:
    # eax: Return values
    # ebx: Pointer to struct
    pushl %ebp
    movl %esp, %ebp

    cmp $0, 8(%ebp)            # Test if arg is a nullptr
    je add_error

    pushl %ebx

    pushl $STRUCT_SIZE          # Allocate space for struct
    call mp1_malloc             # malloc
    add $4, %esp                # Clear arg off frame
    cmp $0, %eax                # Test if result is null
    je add_error                # Error out if so

    movl %eax, %ebx             # Save location of struct

    pushl $STRUCT_SIZE           # ulong n
    pushl 8(%ebp)               # void *from
    pushl %ebx                  # void *to
    call mp1_copy_from_user     # memcpy
    add $12, %esp               # Clear args off frame
    cmp $0, %eax                # Test if result is 0
    jne add_error_free          # Error out if not

    cmpw $1999, LOCATION(%ebx)  # Check if value is within valid range
    ja add_error_free           # Error out if not

    movw ON_LENGTH(%ebx), %ax   # on_length ->
    movw %ax, COUNTDOWN(%ebx)   # countdown
    movw $1, STATUS(%ebx)       # status = 1

    movl mp1_list_head, %edx    # Take head of the list
    movl %edx, NEXT(%ebx)       # Assign it to next node
    movl %ebx, mp1_list_head    # Put this node at head

    movw LOCATION(%ebx), %ax   # offset
    movb ON_CHAR(%ebx), %cl     # char
    call mp1_poke               # poke

    add_error_free:
    pushl %ebx                  # void *ptr
    call mp1_free               # free
    add $4, %esp                # Clear arg off frame

    xor %eax, %eax
    jmp add_done

    add_error:
    movl $-1, %eax

    add_done:
    popl %ebx

    leave
	ret

mp1_ioctl_remove:
    pushl %ebp
    movl %esp, %ebp

    pushl %ebx

    movl mp1_list_head, %ebx

    r_walk:
    end_r_walk:

    remove_error:

    remove_done:
    popl %ebx

    leave
	ret

mp1_ioctl_find:
	ret

mp1_ioctl_sync:
	ret

ioctl_table:
.long mp1_ioctl_add, mp1_ioctl_remove, mp1_ioctl_find, mp1_ioctl_sync

.end
