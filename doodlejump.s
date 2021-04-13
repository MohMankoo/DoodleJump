#####################################################################
#
# Doodle Jump
# ##############
#
# Developer: Mohpreet Mankoo
# ##############
#
# Bitmap Display Configuration:
# ###############
# - Unit width in pixels: 8					     
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Notes
# ###############
# - Sometimes jumps end perfectly on bricks, giving illusion of
#   the player flying.
# - Difficulty changes after every 4 new bricks spawning.
#   Platform size decreases to a minimum of 3 pixel units.
# - Mashing keys or holding for extended periods may crash Mars
# - Leave keyboard simulator at default settings.
#
#####################################################################

# Define data variables
##################################################
.data
# Addresses
	displayAddress:	.word 0x10008000
	keyEventAddress: .word 0xffff0000
	keyPressAddress: .word 0xffff0004

# Colours 
	skyColour: .word 0x574766
	moonColour: .word 0xe8e0cf
	moonShadeColour: .word 0xccc4b1
	moonLightColour: .word 0xf5ecda
	buildingColour: .word 0x382e42

	playerOneColour: .word 0x1f1f1f
	playerOneEyeColour: .word 0xe8e3e3
	playerOneSecColour: .word 0x595959
	byeColour: .word 0xffffff

	normPLatformColour: .word 0xc29e5b
	darkPlatformColour: .word 0x91733c

# Other
	brickLocations: .word 0, 0, 0, 0, 0 # 0 indicates no bricks
	maxScrollsTillNextBrick: .word 8
	jumpHeight: .word 14                # How high player jumps after landing
	repaintLatency: .word 50            # Wait time between repaints in ms
	difficultyChangeFeq: .word 4        # How many new bricks till difficulty change
	
	gameOverUnitStart: .word 3968
	scrollUpUnitStart: .word 1536

.text
# Define register variables
##################################################
	lw $s0, displayAddress      # Base screen address
	lw $s1, skyColour
	li $s2, 8                   # Length of brick platforms
	lw $s3, difficultyChangeFeq # New brick spawns remaining until brick length decreases
	lw $s4, gameOverUnitStart   # Stores address of lowest unit player game over's at
	add $s4, $s0, $s4
	lw $s5, displayAddress      # Indicates player's bottom-left most pixel position
	lw $s6, jumpHeight          # Jumps remaining till gravity takes effect
	li $s7, 4                   # Scrolls remaining till next brick spawns

# Determine & store initial brick locations
##################################################
# t0 stores lower limit, t1 stores upper limit
# for where to draw the brick

# FIRST brick: get_rand_spawn(23, 27)
	li $t0, 23
	li $t1, 27
	addi $sp, $sp, -4
	sw $t0, 0($sp)
	addi $sp, $sp, -4
	sw $t1, 0($sp)
	jal get_rand_spawn

# Set initial player location centered on first brick
	lw $s5, 0($sp)      # Load value of bottom-most brick from stack
	addi $s5, $s5, 16   # Move player 4 units right
	addi $s5, $s5, -128 # Move player 1 unit up

	jal add_brick       # Add result from get_rand_spawn as brick addr

# SECOND brick: get_rand_spawn(14, 16)
	li $t0, 14
	li $t1, 16
	addi $sp, $sp, -4
	sw $t0, 0($sp)
	addi $sp, $sp, -4
	sw $t1, 0($sp)
	jal get_rand_spawn
	jal add_brick

# THIRD brick: get_rand_spawn(7, 10)
	li $t0, 7
	li $t1, 10
	addi $sp, $sp, -4
	sw $t0, 0($sp)
	addi $sp, $sp, -4
	sw $t1, 0($sp)
	jal get_rand_spawn
	jal add_brick

# Repainting loop
##################################################
##################################################
repaint:
	bge $s5, $s4, exit     # Exit if player is touching bottom
	li $v0, 32
	lw $a0, repaintLatency
	syscall                # Sleep for repaintLatency ms

# Brick-player collission detection
##################################################
# if player == touching_brick && jumpsRemaining == 0
# then reset jumps remaining, else move on
	addi $t0, $s5, 128 		# t0 = Pixel addr under p1 left foot
	addi $sp, $sp, -4
	sw $t0, 0($sp)
	jal is_brick       		# Is addr at t0 brick?
	lw $t0, 0($sp)     		# t0 = 1 if addr was brick
	bnez $t0, r_touching_brick 	# Move to next cond. since one foot touching
	
	add $t1, $s5, 136    		# t1 = Pixel addr under p1 right foot
	sw $t1, 0($sp)
	jal is_brick       		# Is addr at t1 brick?
	lw $t1, 0($sp)    		# t1 = 1 if addr was brick
	addi $sp, $sp, 4
	beqz $t1, r_no_brick_collission # Exit since neither foot touching brick

r_touching_brick:
	bnez $s6, r_no_brick_collission # jumpsRemaining != 0
	lw $s6, jumpHeight 		# Reset jumps
r_no_brick_collission:

# Vertical movement
##################################################
# If moving down, move and exit vert movement section
	bnez $s6, r_moving_up  # if not moving down, go up
	addi $s5, $s5, 128     # else move down
	j r_vert_movement_exit # then exit

# If moving up, determine whether to scroll or move p1
r_moving_up:
	lw $t0, scrollUpUnitStart
	add $t0, $t0, $s0             # t0 = addr on screen determining scrolling
	bge $s5, $t0, r_not_scrolling # Don't scroll if p1 address >= t0 address

r_scrolling:
# Scroll up but keep player vertically stationary
	jal move_all_bricks_down
	addi $s7, $s7, -1               # scrollsTillNextBrick--
	beqz $s7, r_scrolling_new_brick # Spawn brick if scrollsTillNextBrick = 0
	j r_moving_up_exit

r_scrolling_new_brick:
# Spawn new brick between (0, 3)
	li $t0, 0
	li $t1, 3
	addi $sp, $sp, -4
	sw $t0, 0($sp)
	addi $sp, $sp, -4
	sw $t1, 0($sp)
	jal get_rand_spawn
	jal add_brick
	
	lw $s7, maxScrollsTillNextBrick # Reset scrollsTillNextBrick

# Update new brick spawns remaining until brick length decreases
	beqz, $s3, r_moving_up_exit     # If already 0 remaining, then ignore
	addi $s3, $s3, -1               # else update timer for length decrease
	j r_moving_up_exit

r_not_scrolling:
# Don't scroll, only move player up
	addi $s5, $s5, -128

r_moving_up_exit:
	addi $s6, $s6, -1 # jumpsRemaining--

r_vert_movement_exit:

# Horizontal movement
##################################################
	lw $t0, keyEventAddress
	lw $t1, 0($t0)                # t1 = key event boolean
	beqz $t1, r_hor_movement_exit # If 0, no key event so exit

# Given that key event happened:
	lw $t2, keyPressAddress
	lw $t3, 0($t2)                       # t3 = key press in ASCII
	beq $t3, 106, r_hor_movement_j_press # 106 = j in ASCII
	beq $t3, 107, r_hor_movement_k_press # 107 = k in ASCII
	j r_hor_movement_exit                # Invalid key pressed so exit

r_hor_movement_j_press:
# If j key pressed, move left
	addi $s5, $s5, -4
	j r_hor_movement_exit

r_hor_movement_k_press:
# If k key pressed, move right
	addi $s5, $s5, 4

r_hor_movement_exit:

# Paint
##################################################
# Decrease brick size if
# timer = 0 && curr_brick_size > 1
	bnez, $s3, r_paint   	    # Skip decrease if timer != 0
	beq, $s2, 1, r_paint 	    # Skip decrease if curr_brick_size <= 1
	addi, $s2, $s2, -1   	    # else decrease platform length
	lw $s3, difficultyChangeFeq # and reset timer

r_paint:
# Paint everything
	jal paint_sky
	jal paint_bricks
	jal paint_p1
	j repaint

###############################################################################

# get_rand_spawn(rowMin, rowMax)
#
# Get a random spawn point between rowMin and rowMax
# and return the address
# - rowMax: should be at top of stack
# - rowMin: should be below rowMax in stack
# - Range of arguments: (0, 31); the higher the lower on screen
##################################################
get_rand_spawn:
# Set t0 = rowMin, t1 = rowMax
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	
# t2 (diff) = rowMax - rowMin + 1
# Then use t2 to get random int for brick offset
	sub $t2, $t1, $t0
	addi $t2, $t2, 1
	move $a1, $t2 # Store upper range for random int generator
	li $v0, 42
	syscall
# t2 (rowOffset) = Random(0, diff)
	move $t2, $a0

# Set t3 as row to spawn brick on
# t3 (spawnRow) = (rowMin + rowOffset) * 128
	add $t3, $t0, $t2
	li $t4, 128
	mult $t3, $t4
	mflo $t3

# Get what column to spawn brick on as
# the offset from the start of corresponding row
# t4 (column offset) = Random(0, 20) * 4
	li $a1, 21 # Store upper range for random int generator
	li $v0, 42
	syscall

	li $t5, 4
	mult $a0, $t5
	mflo $t4

# Set spawnPoint = baseAddress + spawnRow + colOffset
# t5 (spawnPoint) = s0 + t3 + t4
# Drawing of brick begins at t5
	add $t5, $t3, $t4
	add $t5, $t5, $s0

# Set return value as start point of brick
	addi $sp, $sp, -4
	sw $t5, 0($sp)
	jr $ra

# paint_bricks
# Paint bricks given by all valid addresses in brick array
##################################################
paint_bricks:
# t1 = brick array
	la $t1, brickLocations
# t2 = Array loop counter
	li $t2, 0

pb_array_loop: # Outer array loop
	beq $t2, 5, pb_array_loop_exit
	lw $t5, 0($t1)    # Get brick addr at current index
	addi $t1, $t1, 4  # Move to next array index
	addi $t2, $t2, 1  # Update array counter

	bnez $t5, pb_valid_brick # Paint if t5 is non-zero
	j pb_array_loop          # else continue loop

pb_valid_brick:
# t5 = address to paint at
# t6 = address below t5 to draw in parallel
#      to t5 to make a thicker brick
	addi $t6, $t5, 128
	
# t7 = how big to make the brick
# t8 = darker colour for top brick
# t9 = lighter colour for bottom brick
	move $t7, $s2
	lw $t8, darkPlatformColour
	lw $t9, normPLatformColour
	
	sw $t8, 0($t5)   # Paint initial top brick
	addi $t5, $t5, 4 # Update paint address
	addi $t6, $t6, 4

pb_paint_loop:           # Inner paint loop
	beq $t7, 0, pb_paint_loop_exit

# Paint brick at t5 and t6, then update them
# to point to the adjacent unit pixel
	sw $t8, 0($t5)
	sw $t9, 0($t6)
	addi $t5, $t5, 4  # Update paint address
	addi $t6, $t6, 4

	addi $t8, $t8, 8  # Change colours for gradient
	addi $t9, $t9, 8
	addi $t7, $t7, -1 # Update iterator
	j pb_paint_loop

pb_paint_loop_exit:     # Inner paint loop exit
	sw $t8, 0($t5)  # Paint final top brick pixel
	j pb_array_loop # Return to outer array loop

pb_array_loop_exit:     # Outer array loop exit
	jr $ra

# add_brick
# Add address at top of stack to brick addresses array
##################################################
add_brick:
# t0 = brick address to add
	lw $t0, 0($sp)
	addi $sp, $sp, 4
# t1 = brick array
	la $t1, brickLocations
# t2 = loop iterator
	li $t2, 0

# Place address in first non-zero location
# t4 = content of current array index
ab_loop:
	beq $t2, 5, ab_loop_exit # Exit if array searched
	lw $t4, 0($t1)           # Get content at current index
	beqz $t4, ab_loop_found_zero

	add $t1, $t1, 4    	 # Add offset to address
	addi $t2, $t2, 1  	 # Update address offset
	j ab_loop
ab_loop_found_zero:
	sw $t0, 0($t1) # Save brick at current address
ab_loop_exit:
	jr $ra

# move_all_bricks_down
# Moves all visible bricks down one pixel
# Removes a brick if it reaches gameOverUnitStart - 128
##################################################
move_all_bricks_down:
# t1 = brick array
	la $t1, brickLocations
# t2 = Array iterator
	li $t2, 0
# t3 = current brick to move/remove
	li $t3, 0
# t4 = max pixel brick allowed to go
	lw $t4, gameOverUnitStart
	addi $t4, $t4, -128
	add $t4, $s0, $t4

ma_loop:
	beq $t2, 5, ma_loop_exit
	lw $t3, 0($t1)

	beqz $t3, ma_loop_continue         # Ignore curr index if t3 = 0
	bge $t3, $t4, ma_loop_remove_brick # Remove brick if >= offset
	addi $t3, $t3, 128                 # else move it 1 pixel down
	sw $t3, 0($t1)                     # and save it
	j ma_loop_continue
ma_loop_remove_brick:
	li $t3, 0
	sw $t3, 0($t1)    # Replace brick with 0
ma_loop_continue:         # Move to next iteration
	add $t1, $t1, 4   # Add offset to address
	addi $t2, $t2, 1  # Update iterator
	j ma_loop
ma_loop_exit:
	jr $ra

# is_brick
# Return 1 if brick is at address given by top of
# stack, else return 0
##################################################
is_brick:
# t0 = address to check
	lw $t0, 0($sp)
	addi $sp, $sp, 4
# t1 = colour at address to check
	lw $t1, 0($t0)
# t2 = colour offset value
	li $t2, 0
# t3 = return value
	li $t3, 0 # Load 0 for fail by default
# t4 = current colour in loop to check against t1
	lw $t4, darkPlatformColour

ib_loop:
	beq $t2, 80, ib_loop_exit
	lw $t4, darkPlatformColour  # t4 = darkPlatformColour + t2
	add $t4, $t4, $t2
	beq $t4, $t1, ib_loop_match # if addrColour == currentColour

	addi $t2, $t2, 8
	j ib_loop

ib_loop_match:
	li $t3, 1

ib_loop_exit:
	addi $sp, $sp, -4
	sw $t3, 0($sp)
	jr $ra

# Paint sky
##################################################
paint_sky:
	add $t0, $s0, 4092 # Set t0 to address of last screen unit
	lw $t1, skyColour  # Set to initial sky colour
	li $t2, 32         # Use as counter for when to change sky colour

init_sky:
	sw $t1, 0($t0)                    # Set address to sky colour
	beq $t0, $s0, exit_init_sky       # Exit after looping all addresses
	addi $t0, $t0, -4                 # Decrease loop counter

	beq $t2, $zero, change_sky_colour # Change colour for gradient
	addi $t2, $t2, -1                 # Decrease colour counter
	j init_sky

change_sky_colour:
	addi $t1, $t1, -3  # Change colour
	li $t2, 32         # Reset colour counter
	j init_sky

exit_init_sky:
# Paint the moon
	lw $t0, moonColour
	lw $t1, moonShadeColour
	lw $t2, moonLightColour
	addi $t3, $s0, 724 # Set address to paint from
	
	sw $t1, 4($t3)
	sw $t1, 8($t3)
	sw $t0, 12($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	sw $t2, 24($t3)
	sw $t0, 28($t3)
	addi $t3, $t3, -128
	sw $t1, 4($t3)
	sw $t0, 8($t3)
	sw $t0, 12($t3)
	sw $t0, 16($t3)
	sw $t2, 20($t3)
	sw $t0, 24($t3)
	sw $t0, 28($t3)
	addi $t3, $t3, -128
	sw $t0, 8($t3)
	sw $t2, 12($t3)
	sw $t2, 16($t3)
	sw $t2, 20($t3)
	sw $t0, 24($t3)
	addi $t3, $t3, -128
	sw $t2, 12($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	addi $t3, $t3, 512
	sw $t1, 4($t3)
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	sw $t0, 28($t3)
	addi $t3, $t3, 128
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	addi $t3, $t3, 128
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	sw $t1, 20($t3)

# Paint buildings
	lw $t1, buildingColour

	addi $t0, $s0, 3972  # Paint address
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, -128($t0)
	sw $t1, -124($t0)
	sw $t1, -120($t0)
	sw $t1, -116($t0)
	sw $t1, -112($t0)
	sw $t1, -256($t0)
	sw $t1, -252($t0)
	sw $t1, -248($t0)
	sw $t1, -244($t0)
	sw $t1, -384($t0)
	sw $t1, -380($t0)
	sw $t1, -376($t0)
	sw $t1, -372($t0)
	sw $t1, -512($t0)
	sw $t1, -508($t0)
	sw $t1, -504($t0)
	sw $t1, -500($t0)
	sw $t1, -636($t0)
	sw $t1, -632($t0)
	
	addi $t0, $t0, 20    # Update paint address
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, -128($t0)
	sw $t1, -124($t0)
	sw $t1, -120($t0)
	sw $t1, -116($t0)
	sw $t1, -112($t0)
	sw $t1, -108($t0)
	sw $t1, -252($t0)
	sw $t1, -248($t0)
	sw $t1, -244($t0)
	sw $t1, -376($t0)
	
	addi $t0, $t0, 24    # Update paint address
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, -128($t0)
	sw $t1, -124($t0)
	sw $t1, -120($t0)
	sw $t1, -256($t0)
	sw $t1, -252($t0)
	sw $t1, -248($t0)
	sw $t1, -384($t0)
	sw $t1, -380($t0)
	sw $t1, -376($t0)
	
	addi $t0, $t0, 16    # Update paint address
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, -128($t0)
	sw $t1, -124($t0)
	sw $t1, -120($t0)
	sw $t1, -256($t0)
	sw $t1, -252($t0)
	sw $t1, -384($t0)
	sw $t1, -380($t0)
	sw $t1, -512($t0)
	
	addi $t0, $t0, 12    # Update paint address
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, -128($t0)
	sw $t1, -124($t0)
	sw $t1, -120($t0)
	sw $t1, -116($t0)
	sw $t1, -256($t0)
	sw $t1, -252($t0)
	sw $t1, -248($t0)
	sw $t1, -244($t0)
	
	addi $t0, $t0, 16    # Update paint address
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, -128($t0)
	sw $t1, -124($t0)
	sw $t1, -120($t0)
	sw $t1, -256($t0)
	sw $t1, -252($t0)
	sw $t1, -248($t0)
	sw $t1, -384($t0)
	sw $t1, -380($t0)
	sw $t1, -512($t0)
	sw $t1, -508($t0)
	sw $t1, -640($t0)
	sw $t1, -636($t0)
	sw $t1, -764($t0)
	
	addi $t0, $t0, 12    # Update paint address
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, -128($t0)
	sw $t1, -124($t0)
	sw $t1, -120($t0)
	sw $t1, -256($t0)
	sw $t1, -252($t0)
	sw $t1, -248($t0)
	sw $t1, -384($t0)
	sw $t1, -380($t0)
	sw $t1, -512($t0)
	sw $t1, -508($t0)
	sw $t1, -640($t0)
	sw $t1, -636($t0)
	sw $t1, -768($t0)
	
	addi $t0, $t0, 16    # Update paint address
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, -128($t0)
	sw $t1, -124($t0)
	sw $t1, -256($t0)
	sw $t1, -252($t0)
	sw $t1, -384($t0)
	sw $t1, -380($t0)
	jr $ra

# paint_p1
# Paint player one at $s5
##################################################
paint_p1:
	lw $t0, playerOneEyeColour
	lw $t1, playerOneSecColour
	lw $t2, playerOneColour

	sw $t1, 0($s5)
	sw $t1, 8($s5)
	sw $t1, -128($s5)
	sw $t1, -124($s5)
	sw $t1, -120($s5)
	sw $t2, -244($s5)
	sw $t2, -248($s5)
	sw $t2, -252($s5)
	sw $t2, -256($s5)
	sw $t2, -260($s5)
	sw $t0, -376($s5)
	sw $t2, -380($s5)
	sw $t0, -384($s5)
	sw $t2, -504($s5)
	sw $t2, -508($s5)
	sw $t2, -512($s5)
	sw $t2, -632($s5)
	sw $t2, -640($s5)
	jr $ra

# Paint "bye" for Game Over
##################################################
paint_bye:
	lw $t0, byeColour  # t0 = bye colour
	
# Paint b
	add $t1, $s0, 2088 # t1 = address to paint b
	sw $t0, 0($t1)
	sw $t0, 4($t1)
	sw $t0, 8($t1)
	sw $t0, -128($t1)
	sw $t0, -120($t1)
	sw $t0, -256($t1)
	sw $t0, -252($t1)
	sw $t0, -248($t1)
	sw $t0, -384($t1)
	sw $t0, -512($t1)
	
# Paint y
	add $t1, $t1, 16 # t1 = address to paint y
	sw $t0, 0($t1)
	sw $t0, 4($t1)
	sw $t0, 8($t1)
	sw $t0, -128($t1)
	sw $t0, -120($t1)
	sw $t0, -256($t1)
	sw $t0, -248($t1)
	sw $t0, 136($t1)
	sw $t0, 256($t1)
	sw $t0, 260($t1)
	sw $t0, 264($t1)

# Painy e
	add $t1, $t1, 16 # t1 = address to paint e
	sw $t0, 0($t1)
	sw $t0, 4($t1)
	sw $t0, 8($t1)
	sw $t0, -128($t1)
	sw $t0, -256($t1)
	sw $t0, -252($t1)
	sw $t0, -248($t1)
	sw $t0, -384($t1)
	sw $t0, -512($t1)
	sw $t0, -508($t1)
	sw $t0, -504($t1)

# Paint !
	add $t1, $t1, 16 # t1 = address to paint !
	sw $t0, 0($t1)
	sw $t0, -256($t1)
	sw $t0, -384($t1)
	sw $t0, -512($t1)

	jr $ra

# Exit program gracefully
##################################################
exit:
	jal paint_sky
	jal paint_bricks
	jal paint_bye

	li $v0, 10
	syscall
