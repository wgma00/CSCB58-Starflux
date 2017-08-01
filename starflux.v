module starflux (CLOCK_50, KEY, SW, LEDR, LEDG,
                 HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
                 VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_N,
                 VGA_SYNC_N, VGA_R, VGA_G, VGA_B);

	input CLOCK_50; // Default 50 Mhz clock on De2 board
	input [9:0] SW; // Use SW[0] as firing, SW[1] as pause, SW[2] as reset
	input [3:0] KEY; // use KEY[0:3] as right, down, up, left respectively 
	
	output [17:0] LEDR; // LED flash show
	output [8:0] LEDG; // LED flash show
	
	output [6:0] 	HEX0, HEX1, // Display all time high score on HEX[0:1]
						HEX2, HEX3, // Display current high score on HEX[2:3]
						HEX4, HEX5; // Display gun's cooldown timer on HEX[4:5]

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output VGA_CLK;   				//	VGA Clock
	output VGA_HS;						//	VGA H_SYNC
	output VGA_VS;						//	VGA V_SYNC
	output VGA_BLANK_N;				//	VGA BLANK
	output VGA_SYNC_N;				//	VGA SYNC
	output [9:0] VGA_R;   			//	VGA Red[9:0]
	output [9:0] VGA_G;	 			//	VGA Green[9:0]
	output [9:0] VGA_B;   			//	VGA Blue[9:0]
	

	// Game related signals, here we will give useful names to the main 
	// signals which will interact with our starflux game


	wire shoot = SW[0] & (gun_cooldown != 4'hF); // tells our game to shoot bullets from our ship
	wire pause = SW[1]; // tells our game to pause our current state
	wire reset = SW[2]; // tells our game to start from the beginning state

	wire right = ~KEY[0]; // tells our game to move our ship right
	wire down  = ~KEY[1]; // tells our healthgame to move our ship down
	wire up    = ~KEY[2]; // tells our game to move our ship up
	wire left  = ~KEY[3]; // tells our game to move our ship left 

	// Game logic related signals, this is where we'll keep a top level overview
	// of the modules required for our games. 
	 
	 
	wire [3:0]ship_health;  // 8 bit value, we're to display lower four bits on 
                           // HEX6, and upper four bits on HEX7									
   
	wire [3:0]gun_cooldown; // 8 bit value, we're to display lower four bits on 
                           // 4 and upper four bits HEX5

	wire [7:0]current_highscore; // 8 bit value, we're to display on lower four
                                // bits on HEX3 and upper four bits on HEX2
										  
	wire [7:0]alltime_highscore; // 8 bit value, we're to display on lower four
                                // bits on HEX1 and upper four bits on HEX
	
	wire [7:0] user_x, enemy_x; // keeps track of where the user and enemy are on the screen
	wire [6:0] user_y = 7'd119, enemy_y = 7'd0; // keep track of where the user and enemy are on the screen
	
	wire [160*120-10:0]enem_grid; // grid we're gona use for the shifter bit modules for enemy ship

	// Instansiate control and datapath variables 
	wire startGameEn; 
	wire shipUpdateEn, gridUpdateEn;
	wire writeEn; // write enable to plot stuff on VGA screen
	wire gameOverEn; // signalling the ledg and ledr's when the game is in gameover state.
	wire [2:0] colour; // 3 bit (R,G,B) value to be displatyed on VGA
	wire [7:0] x; // 8 bit x value because of our screen resolution
	wire [6:0] y; // 7 bit y value because of our screen resolution
	wire gameover; // 1 bit value to signal gameover
	wire clk_with_interupt = (~gameOverEn) & (~pause) & CLOCK_50; // pause all updates to logic handler and datapath when gameOverEn=1'b1 or pause=1'1

	
	// Instansiate FSM control and writing handler
	// which determines when we're going to draw stuff
	// on screen and ours ships and grids
	control C0(
			.clk(CLOCK_50),
			.reset(reset),
			.startGameEn(startGameEn),
			.shipUpdateEn(shipUpdateEn), 
			.gridUpdateEn(gridUpdateEn),
			.writeEn(writeEn),
			.gameOverEn(gameOverEn),
			.ship_health(ship_health),
			.current_highscore(current_highscore)
	);
 
			
	// Instatiates logic controller which makes changes
	// to our ships and grid, based on the FSM logic from
	// the controller
	logic_handler(
		.clk(clk_with_interupt), 
		.reset(reset), 
		.right(right), 
		.left(left), 
		.shoot(shoot), 
		.startGameEn(startGameEn), 
		.shipUpdateEn(shipUpdateEn), 
		.gridUpdateEn(gridUpdateEn), 
		.user_x(user_x), 
		.user_y(user_y),
		.enemy_x(enemy_x),
		.enemy_y(enemy_y),
		.gun_cooldown(gun_cooldown), 
		.enem_grid(enem_grid),
		.ship_health(ship_health), 
		.current_highscore(current_highscore), 
		.alltime_highscore(alltime_highscore)
	);
	
	// Instatiates datapah  handle logic for displaying stuff
   //	to our VGA screen in this case we handle logic for our
   //	selection of triplets (X, Y, COLOUR)
	datapath d1(
		.clk(clk_with_interupt),
		.startGameEn(startGameEn),
		.user_x(user_x),
		.user_y(user_y),
		.enemy_x(enemy_x),
		.enemy_y(enemy_y),
		.enem_grid(enem_grid),
		.x(x),
		.y(y),
		.colour(colour)
	);
	
	// display ship health (F-0) on HEX5
	hex_decoder_always h5(
		.hex_digit(ship_health[3:0]), 
		.segments(HEX5)
	);
	// display gun cooldown (0-F) on HEX4
	hex_decoder_always h4(
		.hex_digit(gun_cooldown[3:0]), 
		.segments(HEX4)
	);
	
	// display the user's current score (0-FF) on
	// HEX3 and HEX2
	hex_decoder_always h3(
		.hex_digit(current_highscore[7:4]), 
		.segments(HEX3)
	); 
	hex_decoder_always h2(
		.hex_digit(current_highscore[3:0]), 
		.segments(HEX2)
	);
	
	// display the all time high score (0-FF) on
	// HEX1 and HEX0
	hex_decoder_always h1(
		.hex_digit(alltime_highscore[7:4]), 
		.segments(HEX1)
	);
	hex_decoder_always h0(
		.hex_digit(alltime_highscore[3:0]), 
		.segments(HEX0)
	);

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well asHEX the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(~reset),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
		
	// funky stuff we'll display on the LEDs once health
	// becomes 0 or the usrs reaches the maximum possible 
	// score FF
	gameover game_over(
		.ledr(LEDR[17:0]),
		.ledg(LEDG[8:0]),
		.clk(CLOCK_50), 
		.reset(reset),
		.gameover(gameOverEn)
	);
	

endmodule
