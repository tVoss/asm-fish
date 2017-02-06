
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

    xorl %eax, %eax                  # Clear out eax
    xorl %edx, %edx

    movl mp1_list_head, %ebx        # Set ebx to head of the list

    walk:
        cmpl $0, %ebx                # If pointer is null break out of loop
        je end_walk
        subw $1, COUNTDOWN(%ebx)         # Decrement counter
        jnz no_poke
            xor %edx, %edx                  # Clear out edx
            movw STATUS(%ebx), %dx           # Grab status and put it in edx
            movb ON_CHAR(%ebx, %edx, 1), %cl   # Swaps char and puts it in cl
            movw LOCATION(%ebx), %ax         # Moves location to eax
            shlw $1, %ax
            pushl %edx
            call mp1_poke                   # edx gets clobbered
            popl %edx
            movw ON_LENGTH(%ebx, %edx, 2), %ax
            movw %ax, COUNTDOWN(%ebx)        # Puts appropriate length in place
            xorw $1, STATUS(%ebx)            # Flip status
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
    cmpl $3, %eax                # Check if number is greater than 3
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

    cmpl $0, 8(%ebp)            # Test if arg is a nullptr
    je add_error

    pushl %ebx

    pushl $STRUCT_SIZE          # Allocate space for struct
    call mp1_malloc             # malloc
    addl $4, %esp                # Clear arg off frame
    cmpl $0, %eax                # Test if result is null
    je add_error                # Error out if so

    movl %eax, %ebx             # Save location of struct

    pushl $STRUCT_SIZE           # ulong n
    pushl 8(%ebp)               # void *from
    pushl %ebx                  # void *to
    call mp1_copy_from_user     # memcpy
    addl $12, %esp               # Clear args off frame
    cmpl $0, %eax                # Test if result is 0
    jne add_error_free          # Error out if not

    cmpw $1999, LOCATION(%ebx)  # Check if value is within valid range
    ja add_error_free           # Error out if not

    movw ON_LENGTH(%ebx), %ax   # on_length ->
    movw %ax, COUNTDOWN(%ebx)   # countdown
    movb $1, STATUS(%ebx)       # status = 1

    movl mp1_list_head, %edx    # Take head of the list
    movl %edx, NEXT(%ebx)       # Assign it to next node
    movl %ebx, mp1_list_head    # Put this node at head

    movw LOCATION(%ebx), %ax    # offset
    shlw $1, %ax                # x2 (2 bytes per location)
    movb ON_CHAR(%ebx), %cl     # char
    call mp1_poke               # poke

    jmp add_done                # skip error code

    add_error_free:
    pushl %ebx                  # void *ptr
    call mp1_free               # free
    addl $4, %esp                # Clear arg off frame

    xorl %eax, %eax
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

    movl 8(%ebp), %edx          # Get location to remove
    leal mp1_list_head, %eax    # Address of next pointer
    movl mp1_list_head, %ebx    # Get the first element

    r_walk:
        cmpl $0, %ebx               # If null
        je remove_error             # Error out
        cmpw LOCATION(%ebx), %dx    # Check location
        je r_found                  # If match operate on it
        leal NEXT(%ebx), %eax       # Pointer to next node
        movl NEXT(%ebx), %ebx       # Next node
        jmp r_walk                  # Loop

    r_found:
    movl NEXT(%ebx), %ecx       # Get address of next node
    movl %ecx, (%eax)           # Point prev node to next
    pushl %ebx                  # Push pointer to node
    call mp1_free               # free it
    popl %ebx                   # pop it
    movl $0, %eax               # set ok error code
    jmp remove_done

    remove_error:
    movl $-1, %eax              # No element was found

    remove_done:
    popl %ebx

    leave
	ret

mp1_ioctl_find:
    # eax Return
    # ebx Current node
    # ecx Location
    # edx Reference node
    pushl %ebp
    movl %esp, %ebp

    pushl %ebx

    movl 8(%ebp), %edx          # Get reference element
    cmpl $0, %edx               # See if it's null
    jz f_done                   # Finish if it is
    movw LOCATION(%edx), %cx    # Hold on to location
    movl mp1_list_head, %ebx    # Get the first element

    f_walk:
        cmpl $0, %ebx               # See if pointer is null
        je f_error                  # If so error out
        cmpw LOCATION(%ebx), %cx    # Compare to reference location
        je f_found                  # If equal handle it
        movl NEXT(%ebx), %ebx   # Otherwise move to next node
        jmp f_walk                  # Loop

    f_found:
        pushl $STRUCT_SIZE
        pushl %ebx
        pushl %edx
        call mp1_copy_to_user
        addl $12, %esp              # Clear args off frame
        cmpl $0, %eax               # Test if result is 0
        jne f_error                 # Error out if not
        movl $0, %eax               # Set return value to 0
        jmp f_done

    f_error:
    movl $-1, %eax

    f_done:
    popl %ebx

    leave
	ret

mp1_ioctl_sync:
    pushl %ebp
    movl %esp, %ebp

    pushl %ebx                  # Save register
    pushl %esi
    pushl %edi

    movw 8(%ebp), %di           # Get source and dest location
    movw 10(%ebp), %si

    movl mp1_list_head, %ebx    # Start at head of list

    s_walk_s:
        cmpl $0, %ebx               # See if node is nul
        je s_error                  # Error out if so
        cmpw LOCATION(%ebx), %si    # See if location mathes source
        je s_found                  # Handle it if so
        movl NEXT(%ebx), %ebx       # Otherwise go to next node
        jmp s_walk_s                # Loop

    s_found:
    movl %ebx, %esi             # Move address in ebx to source reg
    movl mp1_list_head, %ebx    # Restart for destination

    s_walk_d:                       # Same loop as source
        cmpl $0, %ebx
        je s_error
        cmpw LOCATION(%ebx), %di
        je d_found
        movl NEXT(%ebx), %ebx
        jmp s_walk_d

    d_found:
    movl %ebx, %edi             # Move address in ebx to dest reg

    movl $0, %edx               # Clear edx

    movw ON_LENGTH(%esi), %dx   # Copy on length
    movw %dx, ON_LENGTH(%edi)

    movw OFF_LENGTH(%esi), %dx  # Copy off length
    movw %dx, OFF_LENGTH(%edi)

    movw COUNTDOWN(%esi), %dx   # Copy Countdown
    movw %dx, COUNTDOWN(%edi)

    movw STATUS(%esi), %dx      # Copy Status
    movw %dx, STATUS(%edi)

    notw %dx                        # Flip status
    movb ON_CHAR(%edi, %edx), %cl   # Grab char
    movl $0, %eax                   # Clear eax
    movw LOCATION(%edi), %ax        # Grab location
    shlw %ax                        # x2
    call mp1_poke

    movl $0, %eax                   # Set ok error code
    jmp s_done

    s_error:
    movl $-1, %eax

    s_done:
    popl %edi
    popl %esi
    popl %ebx

    leave
    ret

ioctl_table:
.long mp1_ioctl_add, mp1_ioctl_remove, mp1_ioctl_find, mp1_ioctl_sync

.end
