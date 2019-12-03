module    D_Cache(     
    input                CLK,    
    input                RESET,
	//input			     FLUSH,
    // DRAM write     
	output			DRAM_wr_req,
    output        [31:0] DRAM_wr_addr,   // write data address
    output reg    [31:0] DRAM_wr_data,   // write data
    input                DRAM_wr_valid,  // write a word valid
    // DRAM read    
    output               DRAM_rd_req,    // req to read data from DRAM
    output        [31:0] DRAM_rd_addr,   // address to read data from
    input         [31:0] DRAM_rd_data,   // data read from DRAM
    input                DRAM_rd_valid,  // valid data achieved from DRAM
    // MEM 
	input 		  [31:0] instruction,    
    input         [31:0] MEM_addr,       // address to Read or write to cache
    input                MEM_data_req,   // data request
    input                wren,           // write/read
    input         [31:0] MEM_wr_data,    // write data coming from MEM to DRAM
	input		   [1:0] MEM_wr_size,

    output reg    [31:0] MEM_rd_data,    // data read and send to MEM
    output               hit,            // cache hit or miss
    output               stall_DC,        // if miss, stall until data is get from DRAM
	output	reg	  [0:31] D_SRAM_block [7:0],
	output	reg	  [255:0] D_SRAM_blockk1,
	output	reg	  [255:0] D_SRAM_blockk2,
	output	reg		[0:1]	 v_dirty1,
    output  reg     [0:1]        v_dirty2,
	output reg			[17:0]	 tag1_DM,
	output reg 			[17:0]	 tag2_DM,
	output	reg			 lru_DM,
	output	reg		[17:0] tag_MEMM,
	
	output		 		 dBlkwrite,
	output		 [255:0] block_write_2DM,
	//********************************************************************
	input         		 sys_DC,
	output reg	  [10:0] j,
	output reg	  [10:0] k
	//********************************************************************
);

    parameter            BLOCK_SIZE    =    7;
    parameter            MEM_EXEC      =    0;
    parameter            WR_DRAM       =    1;
    parameter            RD_DRAM       =    2;

    integer              i;
    //reg           [10:0] j;
	//reg			  [10:0] k;
	reg					 flip; 
    reg            [1:0] state;              // State Machine


	assign  	     D_SRAM_blockk1 = {D_SRAM1[index][0], D_SRAM1[index][1], 
										D_SRAM1[index][2], D_SRAM1[index][3],
										D_SRAM1[index][4],D_SRAM1[index][5],
										D_SRAM1[index][6],D_SRAM1[index][7]};
	assign	  		 D_SRAM_blockk2 = {D_SRAM2[index][0], D_SRAM2[index][1], 
										D_SRAM2[index][2], D_SRAM2[index][3],
										D_SRAM2[index][4],D_SRAM2[index][5],
										D_SRAM2[index][6],D_SRAM2[index][7]};

	assign				 v_dirty1 =valid_dirty1[index];
    assign               v_dirty2 = valid_dirty2[index];
	assign			tag1_DM = tag1[index];
	assign			tag2_DM = tag2[index];
	assign				 lru_DM = lru [index];
	assign			tag_MEMM = tag_MEM;

    wire          [0:31] D_SRAM_block [0:7];
	wire		  [0:31] D_SRAM_block1 [0:7];
	wire		  [0:31] D_SRAM_block2 [0:7];
	assign				 D_SRAM_block = hit1 ? D_SRAM1[index][0:7] :  (hit2? D_SRAM2[index][0:7] : 0);  // { state(1), dirty(1), tag(18), data(8*32) } 
    reg           [0:31] D_SRAM_word;
	assign			     D_SRAM_word = D_SRAM_block[MEM_addr[4:2]];
    reg            [0:1] valid_dirty1 [511:0];              // valid/dirty bit
	reg 		   [0:1] valid_dirty2 [511:0];

	reg		      [17:0] tag1 [511:0];
	reg		  	  [17:0] tag2 [511:0];
	reg					 lru  [511:0]; // 0 to evict 1, 1 to evict 2
	wire				 hit1       = valid_dirty1[index][0] & (tag1[index] == tag_MEM);
	wire				 hit2       = valid_dirty2[index][0] & (tag2[index] == tag_MEM);
	assign				 hit		= hit1 | hit2;
	wire 		   [8:0] index 		= MEM_addr[13:5];
	wire		  [17:0] tag_MEM 	= MEM_addr[31:14];
	wire		   [4:0] offset 	= MEM_addr[4:0];

    reg           [31:0] MEM_addr_backup;    // MEM address backup
    reg           [31:0] MEM_wr_data_backup; // MEM write data backup

	reg			  [31:0] MEM_wr_data_shifted;
    reg                  MEM_wr_wait_flag;   // MEM write wait flag

    wire                 DRAM_wr_ready;      // write data to DRAM ready
    wire                 DRAM_rd_ready;      // DRAM data to be read ready

    reg                  DRAM_rd_req_dly;    // reading request delay

    reg           [31:0] wr_counter;         // counter for block writing and reading
    reg           [31:0] rd_counter;

    reg           [0:31] DRAM_data_shift[7:0];     // 8*32 shift registers to store an entire block
    reg           [0:31] D_SRAM1[511:0][0:7];           // the data_cache storage
	reg			  [0:31] D_SRAM2[511:0][0:7];
	
	reg			  [31:0]  instr_dly;
    reg           [31:0]  shift_val;
	reg 		  [31:0]  shift_val_backup;

	wire 				 FLUSH = (sys_DC) & (j < 1024);
	reg			  [31:0] FLUSH_addr;
	//wire			     DRAM_wr_req;
	wire				 dBlkw_flush;
	reg			 [255:0] block_write_flush;
    assign shift_val = (MEM_wr_size == 0) ? MEM_wr_size : ((4 - MEM_wr_size) * 8);
	assign MEM_wr_data_shifted = {MEM_wr_data << shift_val};

    
	always @(posedge CLK or negedge RESET) begin
		 if (!RESET) begin
			j <= 0;
			k <= 0;
			flip <= 0;
         end else if (FLUSH) begin
            if (j < 1024) begin
				case (flip)
					0: begin
						dBlkw_flush 	   <= valid_dirty1[k[8:0]][1];
					valid_dirty1[k[8:0]]   <= 0;
					block_write_flush	   <= { D_SRAM1[k[8:0]][0], D_SRAM1[k[8:0]][1],
												D_SRAM1[k[8:0]][2], D_SRAM1[k[8:0]][3],
												D_SRAM1[k[8:0]][4], D_SRAM1[k[8:0]][5],
												D_SRAM1[k[8:0]][6], D_SRAM1[k[8:0]][7]};
						FLUSH_addr				<= {tag1[k[8:0]], k[8:0],5'b0};
						j						<= j + 1'b1; 
                        flip                    <= ~flip;
					end
					1: begin
						dBlkw_flush 	   		<= valid_dirty2[k[8:0]][1];
						valid_dirty2[k[8:0]]    <= 0;
						block_write_flush	    <= { D_SRAM2[k[8:0]][0], D_SRAM2[k[8:0]][1],
													 D_SRAM2[k[8:0]][2], D_SRAM2[k[8:0]][3],
													 D_SRAM2[k[8:0]][4], D_SRAM2[k[8:0]][5],
													 D_SRAM2[k[8:0]][6], D_SRAM2[k[8:0]][7]};
						FLUSH_addr				<= {tag2[k[8:0]], k[8:0],5'b0};
						j						<= j + 1'b1;
                        k                       <= k + 1'b1; 
                        flip                    <= ~flip;
					end
					//default: begin
                      //  flip                    <= 0;
                        //j                       <= j + 1;
                        //k                       <= k + 1；
					//end
				endcase
			end
			$display("\n DCache: ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
			$display("MEM:Instr1_OUT= %x,Instr1_dly= %x",instruction,instr_dly);
			$display("DCache(DRAM): dBlkWrite(%d, %d, %d - %d): %x", dBlkwrite,j-1, k, flip, block_write_2DM);
			$display("DCache(DRAM): D_SRAM1(%d): %x", k,D_SRAM1[k[8:0]][0:7]);
			$display("DCache(DRAM): D_SRAM2(%d): %x", k,D_SRAM2[k[8:0]][0:7]);
			$display("\n vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv");
		 end else if (~sys_DC) begin 
			j <= 0;
			k <= 0;
			flip <= 0;
		 end
    end
    
    // MEM/DRAM writes to data_cache

    always @(posedge CLK or negedge RESET) begin
        if (!RESET) begin 
            for(i=0;i<511;i=i+1) begin
                valid_dirty1[i]    =    0;
                valid_dirty2[i]    =    0; 
            end
            //to change to two way, index: [13:5], tag [31:14]
            //or two hit signals and implement lru
            //512 blocks, 256 bit per block, 8 word per block, 9 bit index [13:5], 3 bit for offset [4:2], 18 bit tag [31:14], 1 bit valid, 1 bit dirty.
            //cache size 2^10 * (256 + 17 + 1 +M 1) = 2^9 * 275        
        end else if (FLUSH) begin

		end else if(DRAM_rd_ready) begin   // DRAM write cache block         
            //put the block from DRAM into D_cache
			case (lru[MEM_addr_backup[13:5]])
				0: begin
				    D_SRAM1[MEM_addr_backup[13:5]][0]  <= DRAM_data_shift[1]; 
					D_SRAM1[MEM_addr_backup[13:5]][1]  <= DRAM_data_shift[2]; 
					D_SRAM1[MEM_addr_backup[13:5]][2]  <= DRAM_data_shift[3]; 
					D_SRAM1[MEM_addr_backup[13:5]][3]  <= DRAM_data_shift[4]; 
					D_SRAM1[MEM_addr_backup[13:5]][4]  <= DRAM_data_shift[5];
					D_SRAM1[MEM_addr_backup[13:5]][5]  <= DRAM_data_shift[6]; 
					D_SRAM1[MEM_addr_backup[13:5]][6]  <= DRAM_data_shift[7]; 
					D_SRAM1[MEM_addr_backup[13:5]][7]  <= DRAM_rd_data; 
					valid_dirty1[MEM_addr_backup[13:5]]<= 2'b10;
					tag1[MEM_addr_backup[13:5]]		   <= MEM_addr_backup[31:14];
					lru[MEM_addr_backup[13:5]] = ~lru[MEM_addr_backup[13:5]];
				   end
				1: begin
				    D_SRAM2[MEM_addr_backup[13:5]][0]  <= DRAM_data_shift[1]; 
					D_SRAM2[MEM_addr_backup[13:5]][1]  <= DRAM_data_shift[2]; 
					D_SRAM2[MEM_addr_backup[13:5]][2]  <= DRAM_data_shift[3]; 
					D_SRAM2[MEM_addr_backup[13:5]][3]  <= DRAM_data_shift[4]; 
					D_SRAM2[MEM_addr_backup[13:5]][4]  <= DRAM_data_shift[5];
					D_SRAM2[MEM_addr_backup[13:5]][5]  <= DRAM_data_shift[6]; 
					D_SRAM2[MEM_addr_backup[13:5]][6]  <= DRAM_data_shift[7]; 
					D_SRAM2[MEM_addr_backup[13:5]][7]  <= DRAM_rd_data; 
					valid_dirty2[MEM_addr_backup[13:5]]<= 2'b10;
					tag2[MEM_addr_backup[13:5]]		   <= MEM_addr_backup[31:14];
					lru[MEM_addr_backup[13:5]] = ~lru[MEM_addr_backup[13:5]];
				end
			default: begin
				    D_SRAM1[MEM_addr_backup[13:5]][0]  <= DRAM_data_shift[1]; 
					D_SRAM1[MEM_addr_backup[13:5]][1]  <= DRAM_data_shift[2]; 
					D_SRAM1[MEM_addr_backup[13:5]][2]  <= DRAM_data_shift[3]; 
					D_SRAM1[MEM_addr_backup[13:5]][3]  <= DRAM_data_shift[4]; 
					D_SRAM1[MEM_addr_backup[13:5]][4]  <= DRAM_data_shift[5];
					D_SRAM1[MEM_addr_backup[13:5]][5]  <= DRAM_data_shift[6]; 
					D_SRAM1[MEM_addr_backup[13:5]][6]  <= DRAM_data_shift[7]; 
					D_SRAM1[MEM_addr_backup[13:5]][7]  <= DRAM_rd_data; 
					valid_dirty1[MEM_addr_backup[13:5]]<= 2'b10;
					tag1[MEM_addr_backup[13:5]]		   <= MEM_addr_backup[31:14];
					lru[MEM_addr_backup[13:5]] = ~lru[MEM_addr_backup[13:5]];
			end
			endcase
        end else if( hit & MEM_data_req & wren ) begin // write dirty bit
            //if hit, MEM write into a block in D_cache
			case (hit1)
				0: begin
					valid_dirty2[index][1]		<= 1'b1;
					case (MEM_wr_size)
						0: begin 
								D_SRAM2[index][offset[4:2]] <= MEM_wr_data_shifted;
						end
						1: begin
								D_SRAM2[index][offset[4:2]][8*MEM_addr[1:0] +:8] <= MEM_wr_data_shifted[31:24];
						end
						2: begin
								D_SRAM2[index][offset[4:2]][8*MEM_addr[1:0] +:16] <= MEM_wr_data_shifted[31:16];
						end
						3: begin
								D_SRAM2[index][offset[4:2]][8*MEM_addr[1:0] +:24] <= MEM_wr_data_shifted[31:8];
						end

					endcase 
				end
				1: begin
					valid_dirty1[index][1]		<= 1'b1;
					case (MEM_wr_size)
						0: begin 			
								D_SRAM1[index][offset[4:2]] <= MEM_wr_data_shifted;
						end
						1: begin
								D_SRAM1[index][offset[4:2]][8*MEM_addr[1:0] +:8] <= MEM_wr_data_shifted[31:24];
						end
						2: begin
								D_SRAM1[index][offset[4:2]][8*MEM_addr[1:0] +:16] <= MEM_wr_data_shifted[31:16];
						end
						3: begin
								D_SRAM1[index][offset[4:2]][8*MEM_addr[1:0] +:24] <= MEM_wr_data_shifted[31:8];
						end
					endcase 
				end
			endcase


			/*case(shift_val/8)*/

        end else if( MEM_wr_wait_flag & ( {DRAM_rd_req_dly,DRAM_rd_req} == 2'b10 ) ) begin // write dirty bit 
			case (lru[MEM_addr_backup[13:5]])//putting data from MEM into DRAM
				0: begin
					valid_dirty2[MEM_addr_backup[13:5]][1] <= 1'b1;
					case (shift_val_backup / 8)
						0: begin
							D_SRAM2[MEM_addr_backup[13:5]][MEM_addr_backup[4:2]] <= MEM_wr_data_backup;
						end
						1: begin
							D_SRAM2[MEM_addr_backup[13:5]][MEM_addr_backup[4:2]][8*MEM_addr_backup[1:0] +:24] <= MEM_wr_data_backup[31:8];
						end
						2: begin
							D_SRAM2[MEM_addr_backup[13:5]][MEM_addr_backup[4:2]][8*MEM_addr_backup[1:0] +:16] <= MEM_wr_data_backup[31:16];
						end
						3: begin
							D_SRAM2[MEM_addr_backup[13:5]][MEM_addr_backup[4:2]][8*MEM_addr_backup[1:0] +:8] <= MEM_wr_data_backup[31:24];
						end
					endcase
				end
				1: begin
					valid_dirty1[MEM_addr_backup[13:5]][1] <= 1'b1;
					D_SRAM1[MEM_addr_backup[13:5]][MEM_addr_backup[4:2]] <= MEM_wr_data_backup;
				end
				default: begin
				end
			endcase
            		
            // if miss, move the target data block into cache, before taking from MEM, write the backup of the original data into D-Cache (____backup).
 
        end     
    end     // data_cache writes DRAM     


	always @(posedge CLK)begin
		if (RESET) begin
			instr_dly <= instruction;
		end
	end

	assign 	  dBlkwrite  = FLUSH? dBlkw_flush : DRAM_wr_req;

	reg		  [255:0] block_now;
	assign 		block_now = lru[MEM_addr_backup[13:5]]? {D_SRAM2[index][0], D_SRAM2[MEM_addr_backup[13:5]][1],
                                                                D_SRAM2[MEM_addr_backup[13:5]][2], D_SRAM2[MEM_addr_backup[13:5]][3],
                                                                D_SRAM2[MEM_addr_backup[13:5]][4], D_SRAM2[MEM_addr_backup[13:5]][5],
                                                                D_SRAM2[MEM_addr_backup[13:5]][6], D_SRAM2[MEM_addr_backup[13:5]][7]} : 
                                                                {D_SRAM1[index][0], D_SRAM1[MEM_addr_backup[13:5]][1],
                                                                D_SRAM1[MEM_addr_backup[13:5]][2], D_SRAM1[MEM_addr_backup[13:5]][3],
                                                                D_SRAM1[MEM_addr_backup[13:5]][4], D_SRAM1[MEM_addr_backup[13:5]][5],
                                                                D_SRAM1[MEM_addr_backup[13:5]][6], D_SRAM1[MEM_addr_backup[13:5]][7]};

	assign    block_write_2DM = FLUSH ? block_write_flush : block_now; 

    //take the correct word out of D_SRAM_block and later give it to MEM
    // set hit and dirty bit(if the block has been changed by MEM)
    assign    MEM_rd_data     =    (hit & MEM_data_req & ~wren)? /*D_SRAM_word*/(hit1? D_SRAM1[index][MEM_addr[4:2]]:D_SRAM2[index][MEM_addr[4:2]]) : MEM_rd_data;     
    assign    D_SRAM_block1    =    D_SRAM1[index]; 
	assign    D_SRAM_block2    =    D_SRAM2[index]; 
 	
	wire 	  dirty;
	wire	  dirty1;
	wire	  dirty2;
   	assign	  dirty	    = 	 lru[index] ? dirty2 : dirty1;
    assign    dirty1    =    valid_dirty1[index][1];     
	assign    dirty2    =    valid_dirty2[index][1]; 
	// write/read data_cache miss, waiting...     
    assign    stall_DC = ( DRAM_wr_req || DRAM_rd_req || FLUSH || ((instruction != instr_dly) & MEM_data_req)); // data_cache state machine     

    //state machine
    always@(posedge CLK or negedge RESET) begin         
        if(!RESET | FLUSH) begin             
            state    <=    MEM_EXEC;         
        end else begin            
            case(state)                 
                MEM_EXEC:   
                    if( ~hit & dirty & MEM_data_req ) begin    // dirty block write back to DRAM                           
                        state    <=    WR_DRAM;                         
                    end else if( ~hit & MEM_data_req & ~({DRAM_rd_req_dly,DRAM_rd_req} == 2'b10) ) begin   // request new block from DRAM                             
                        state    <=    RD_DRAM;                      
                    end else begin                            
                        state    <=    MEM_EXEC;
                    end                 
                WR_DRAM:
                    if(DRAM_wr_ready) begin                   
                        state    <=    RD_DRAM;                      
                    end else begin                            
                        state    <=    WR_DRAM;
                    end                 
                RD_DRAM:
                    if(DRAM_rd_ready) begin                           
                        state    <=    MEM_EXEC;                 
                    end else begin
                        state    <=    RD_DRAM;
                    end
                default:state    <=    MEM_EXEC;                 
            endcase 
        end    
    end               
    assign    DRAM_wr_req    =    ( WR_DRAM == state );     // DRAM write/read req
    assign    DRAM_rd_req    =    ( RD_DRAM == state );
    // DRAM read req delay
    always@(posedge CLK) begin
        DRAM_rd_req_dly    <=    DRAM_rd_req;          
    end

    always@(posedge CLK or negedge RESET) begin
        if( !RESET | FLUSH) begin
            MEM_addr_backup    <=    0;
        end else if( ~hit & MEM_data_req) begin          
            MEM_addr_backup    <=    MEM_addr; 
        end    
    end          // MEM write data backup
        
    always@(posedge CLK or negedge RESET)     begin         
        if( !RESET | FLUSH) begin            
            MEM_wr_data_backup    <=    0;
			shift_val_backup	  <=    0;
            MEM_wr_wait_flag      <=    0;
			DRAM_wr_data    	  <=    0;         
        end else if( ~hit & MEM_data_req & wren )begin             
            MEM_wr_data_backup    <=    MEM_wr_data_shifted;
			shift_val_backup	  <=    shift_val;
            MEM_wr_wait_flag      <=    1;
        end else if ( ~DRAM_wr_req & ~DRAM_rd_req ) begin            
            MEM_wr_wait_flag      <=    0; 
        end    
    end          // MEM write wait flag(wait until target block has been moved to cache)     
        
   // block counter     
    always@(posedge CLK or negedge RESET)     begin         
        if( !RESET | FLUSH)         begin             
            wr_counter    <=    0;             
            rd_counter    <=    0;         
        end else begin             
            if( DRAM_wr_ready ) begin                
                wr_counter    <=    0;             
            end else if( DRAM_wr_valid & DRAM_wr_req ) begin                
                wr_counter    <=    wr_counter + 1'b1;
            end

            if( DRAM_rd_ready ) begin                
                rd_counter    <=    0;             
            end else if( DRAM_rd_valid & DRAM_rd_req  ) begin                 
                rd_counter    <=    rd_counter + 1'b1; 
            end        
        end     
    end // count to BLOCK_SIZE

    //assign to ready bit (DRAM_wr_ready and DRAM_rd_ready)
	assign DRAM_wr_ready = (1 == wr_counter);
    assign DRAM_rd_ready = (BLOCK_SIZE == rd_counter)& ~({DRAM_rd_req_dly,DRAM_rd_req} == 2'b10);
    // write/read address for DRAM     
	wire     [17:0] tag_2DM;
	assign tag_2DM = lru[MEM_addr[13:5]]? tag2[MEM_addr[13:5]] : {tag1[MEM_addr[13:5]]};
    assign    DRAM_wr_addr    =    FLUSH? FLUSH_addr/*( flip ? {tag2[k[8:0]], k[8:0] ,5'b0} : {tag1[k[8:0]], k[8:0],5'b0})*/ : {tag_2DM, MEM_addr[13:5],5'b0 };
    assign    DRAM_rd_addr    =    rd_counter == 0 ? {MEM_addr[31:5], rd_counter[2:0], 2'b0}:{MEM_addr_backup[31:5], rd_counter[2:0], 2'b0}; //address to read from in DRAM
    // DRAM data buffer     
    always@(posedge CLK or negedge RESET)begin
        if( !RESET | FLUSH)  begin             
            DRAM_data_shift[0]    <=    0;             
            DRAM_data_shift[1]    <=    0;             
            DRAM_data_shift[2]    <=    0;             
            DRAM_data_shift[3]    <=    0;             
            DRAM_data_shift[4]    <=    0;             
            DRAM_data_shift[5]    <=    0;             
            DRAM_data_shift[6]    <=    0;             
            DRAM_data_shift[7]    <=    0;         
        end else if( DRAM_rd_ready ) begin             
            DRAM_data_shift[0]    <=    0;             
            DRAM_data_shift[1]    <=    0;             
            DRAM_data_shift[2]    <=    0;             
            DRAM_data_shift[3]    <=    0;             
            DRAM_data_shift[4]    <=    0;             
            DRAM_data_shift[5]    <=    0;             
            DRAM_data_shift[6]    <=    0;             
            DRAM_data_shift[7]    <=    0;         
        end else if(DRAM_rd_valid) begin             
            DRAM_data_shift[0]    <=    DRAM_data_shift[1];             
            DRAM_data_shift[1]    <=    DRAM_data_shift[2];             
            DRAM_data_shift[2]    <=    DRAM_data_shift[3];             
            DRAM_data_shift[3]    <=    DRAM_data_shift[4];             
            DRAM_data_shift[4]    <=    DRAM_data_shift[5];             
            DRAM_data_shift[5]    <=    DRAM_data_shift[6];             
            DRAM_data_shift[6]    <=    DRAM_data_shift[7];             
            DRAM_data_shift[7]    <=    DRAM_rd_data;         
        end     
    end
endmodule
