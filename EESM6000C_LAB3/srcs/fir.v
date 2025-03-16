module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    //aw_
    output  wire                     awready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    
    //w_
    output  wire                     wready,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    
    //ar_
    output  wire                     arready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    
    //r_
    input   wire                     rready,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,   
    
    //ss_
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    
    //sm_
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
begin
	
    // write your code here!
	
	//local
	reg [(pDATA_WIDTH-1):0]status = 32'h0000_0002; 
		//32'h0000_0001//->start
		//32'h0000_0002//->idle 
		//32'h0000_0004//->done
		//32'h0000_0000//->process

	//BRAM_data
    reg [3:0] data_WE_t =               			0;
    reg data_EN_t =                     			0;
    reg signed [(pDATA_WIDTH-1):0] data_Di_t = 	    0 ;
    reg [(pADDR_WIDTH-1):0] data_A_t =  			0;
    assign data_WE =                    			data_WE_t;
    assign data_EN =                    			data_EN_t;
    assign data_Di =                    			data_Di_t;
    assign data_A =                     			data_A_t;
	
    //BRAM_TAP                          			
    reg [3:0] tap_WE_t =                			0;
    reg tap_EN_t =                      			0;
    reg signed [(pDATA_WIDTH-1):0] tap_Di_t =  	    0;
    reg [(pADDR_WIDTH-1):0] tap_A_t =   			0;
    assign tap_WE =                     			tap_WE_t;
    assign tap_EN =                     			tap_EN_t;
    assign tap_Di =                     			tap_Di_t;
    assign tap_A =                      			tap_A_t;
	
	//initial
	reg initial_flag = 								1; 							//1 => system initial needed
	reg [(pDATA_WIDTH-1):0] initial_counter = 		0;
	
	////////////////////////////////////////////////////////initial_start////////////////////////////////////////////////////////
	reg system_ready = 0;
	
	reg signed [(pADDR_WIDTH-1):0] ss_counter = 0;
    reg signed [(pADDR_WIDTH-1):0] ss_counter_data = 0;
    
    reg signed [(pDATA_WIDTH-1):0] y = 0;
    
    reg ss_tready_t = 0;
    assign ss_tready = ss_tready_t;
    
    reg ss_late_sum = 0;
    
    reg start_received = 0;
    reg last_recevied = 0;
    
    
    reg [(pDATA_WIDTH-1):0] sm_tdata_t = 0;
    assign sm_tdata = sm_tdata_t;
    
    reg sm_tvalid_t = 0;
    assign sm_tvalid = sm_tvalid_t;
    
    reg sm_tlast_t = 0;
    assign sm_tlast = sm_tlast_t;
    
        //aw_ and w_
    reg awready_t =                     1'b0;
    reg wready_t =                      1'b0;
    assign awready =                    awready_t;
    assign wready =                     wready_t;
    
    //ar_ and r_
	reg [(pADDR_WIDTH-1):0] r_temp_araddr = 12'hfff;
    reg [(pADDR_WIDTH-1):0] r_counter = 0;
    
    reg arready_t =                     1'b0;
    reg rvalid_t =                      1'b0;
    reg [(pDATA_WIDTH-1):0] rdata_t =   0;
    assign arready =                    arready_t;
    assign rvalid =                     rvalid_t;
    assign rdata =                      rdata_t; 
    
    //local
    reg [pDATA_WIDTH-1:0] data_length = 0;
    
    reg ww_tap_unbind = 0;
    
	always @(posedge axis_clk || axis_rst_n) begin
		if (axis_rst_n == 0) begin
		   initial_flag <= 1;
		end 
		if(initial_flag == 1 && axis_rst_n == 1) begin
		    system_ready <= 0;
		    
            y <= 0;
            ss_counter_data <= 0;
            last_recevied <= 0;
            sm_tdata_t <= 0;
            sm_tvalid_t <= 0;
            
			if (initial_counter < 14) begin
			
				//control status
				if (initial_counter < 13) begin
					status <= 0; //->process
				end 
				else begin
					//turn status
					status <= 2; //->idle
					
					//reset the initial parameter next clk
					initial_flag <= 0;
					system_ready <= 1;
				end
				
				//clear ram
				if (initial_counter < 12) begin
					//clear all in tap_ram
					tap_WE_t <= 4'b1111;
					tap_EN_t <= 1;
					tap_Di_t <= 0;
					tap_A_t  <= (initial_counter << 2);
				end 
				else begin
					tap_WE_t <= 0;
					tap_EN_t <= 0;
					tap_Di_t <= 0;
					tap_A_t  <= 0;
				end 
				
				if (initial_counter < 13) begin
                    //clear all in data ram
                    data_WE_t <= 4'b1111;
                    data_EN_t <= 1;
                    data_Di_t <= 0;
                    data_A_t  <= (initial_counter << 2);
				end 
				else begin 
                    data_WE_t <= 0;
					data_EN_t <= 0;
					data_Di_t <= 0;
					data_A_t  <= 0;
				end 
				
				//update_initial_counter
				initial_counter <= initial_counter + 1;
			end
			else begin // 以防万一
				//turn status
				status <= 2; //->idle
				
				//reset the initial parameter next clk
				initial_flag <= 0;
				initial_counter <= 0;
				
				//turn off RAMs
				tap_WE_t <= 0;
				tap_EN_t <= 0;
				tap_Di_t <= 0;
				tap_A_t  <= 0;
				
				data_WE_t <= 0;
				data_EN_t <= 0;
				data_Di_t <= 0;
				data_A_t  <= 0;
			end 
		end 
		else begin 
			initial_counter <= 0;
		end
	end 
	////////////////////////////////////////////////////////initial_start////////////////////////////////////////////////////////

    always @(posedge axis_clk) begin
        if (status == 32'h0000_0001 && system_ready ) begin 
            status <= 32'h0000_0000;
            start_received <= 1;
        end 
        
        if (ss_tlast && system_ready) begin
            last_recevied <= 1;
        end
        
        if (status == 32'h0000_0000 && last_recevied && start_received && system_ready && ss_counter > 12) begin
            ss_counter <= 0;
            if (last_recevied) begin 
                status <= 32'h0000_0004;
                last_recevied <= 0;
                start_received <= 0;
            end 
        end
        
        if (status == 32'h0000_0000 && ss_tvalid && start_received && system_ready) begin
            if (ss_counter_data < 11) begin
                if (ss_counter < ss_counter_data + 2 && ss_counter >= 0) begin  
                    //读取tap_ram请求
                    tap_EN_t <= 1;
                    tap_A_t <= ss_counter * 4;
                    
                    if (ss_counter == 0) begin
                        data_WE_t <= 4'b1111;
                        data_Di_t <= ss_tdata;
                    end 
                    else begin 
                        data_WE_t <= 0;
                        data_Di_t <= 0;
                    end
                    
                    data_EN_t <= 1;
                    
                    data_A_t <= (ss_counter_data - ss_counter) * 4;
                end     
                else begin
                    //读取tap_ram请求
                    tap_EN_t <= 0;
                    tap_A_t <= 0;
                    
                    //写入并读取data_ram
                    data_WE_t <= 0;
                    data_EN_t <= 0;
                    data_Di_t <= 0;
                    data_A_t <= 0;
                end   
                
                if (ss_counter > 1 && ss_counter < ss_counter_data + 3) begin
                    y <= y + tap_Do * data_Do;
                end
                else begin
                    y <= 0; // for ss_counter == 0 or == 12
                end 
                
                if (ss_counter > ss_counter_data + 2) begin
                    ss_counter <= 0;
                    ss_counter_data <= ss_counter_data + 1;
                end
                else begin
                    ss_counter <= ss_counter + 1;
                end 
                
                if (ss_counter == ss_counter_data + 2) begin
                    ss_tready_t <= 1;
                end 
                else begin
                    ss_tready_t <= 0;
                end 
                         
            end  
            
            else begin
                if (ss_counter < 12 && ss_counter >= 0) begin 
                    //读取tap_ram请求
                    tap_EN_t <= 1;
                    tap_A_t <= ss_counter * 4;
                    
                    //写入并读取ss_data
                    if (ss_counter == 0) begin 
                        data_WE_t <= 4'b1111;
                        data_Di_t <= ss_tdata;
                    end  
                    else begin
                        data_WE_t <= 0;
                        data_Di_t <= 0;
                    end 
                    
                    data_EN_t <= 1;
    
                    if ((ss_counter_data % 11) - ss_counter >= 0) begin
                        data_A_t <= ((ss_counter_data % 11) - ss_counter) * 4;
                    end 
                    else begin
                        data_A_t <= ((ss_counter_data % 11) - ss_counter + 11) * 4; 
                        
                    end 
                    
                end
                else begin
                    //读取tap_ram请求
                    tap_EN_t <= 0;
                    tap_A_t <= 0;
                    
                    //写入并读取data_ram
                    data_WE_t <= 0;
                    data_EN_t <= 0;
                    data_Di_t <= 0;
                    data_A_t <= 0;
                end 
                
                if (ss_counter > 0 && ss_counter < 13) begin
                    y <= y + tap_Do * data_Do;
                end
                else begin
                    y <= 0; // for ss_counter == 0 or == 12
                end 
                
                if (ss_counter > 12) begin
                    ss_counter <= 0;
//                    if (last_recevied) begin 
//                        status <= 32'h0000_0004;
//                        last_recevied <= 0;
//                        start_received <= 0;
//                    end 
                end
                else begin
                    ss_counter <= ss_counter + 1;
                end 
                
                if (ss_counter == 12) begin
                    ss_tready_t <= 1;
                    ss_counter_data <= ss_counter_data + 1;
                end 
                else begin
                    ss_tready_t <= 0;
                end 
            end
        end
    end

    always @(posedge axis_clk) begin
        if ((status == 32'h0000_0000 || status == 32'h0000_0004) && system_ready) begin
            if (sm_tready && ss_tready_t) begin
                sm_tdata_t <= y;
                sm_tvalid_t <= 1;
                if (last_recevied) begin
                     sm_tlast_t <= 1;
                end 
            end
            else begin 
                sm_tdata_t <= 0;
                sm_tvalid_t <= 0;
            end 
            
            if (sm_tlast_t) begin 
                sm_tlast_t <= 0;
            end 
        end 
    end 
        




	//start
	////////////////////////////////////////////////////////idle_start////////////////////////////////////////////////////////
	always @(posedge axis_clk) begin
        if ((awvalid || wvalid) && status == 32'h0000_0002 && system_ready) begin
            if (awvalid) begin 
                awready_t <= 1'b1;
            end
            else begin
                awready_t <= 1'b0;
            end 
            
            if (wvalid) begin 
                wready_t <= 1'b1;
            end 
            else begin
                wready_t <= 1'b0;
            end
            
            if (wready_t && awready_t) begin // 写入data_length
                if (awaddr==12'h00 && wdata == 32'h0000_0001) begin//更改状态
                    status <= wdata;
                end 
                else if (awaddr==12'h10) begin//写入数据长度
                    data_length <= wdata;
                end 
                else if((awaddr-12'h20)>= 0 && (awaddr-12'h20)<= 11*4) begin
                    tap_WE_t <= 4'b1111;
                    tap_EN_t <= 1;
                    tap_Di_t <= wdata;
                    tap_A_t  <= (awaddr-12'h20);
                    ww_tap_unbind <= 1;
                end 
            end
        end
        else if (system_ready) begin
            awready_t <= 1'b0;
            wready_t <= 1'b0;
            if (ww_tap_unbind)begin 
                tap_WE_t <= 0;
                tap_EN_t <= 0;
                tap_Di_t <= 0;
                tap_A_t  <= 0;  
                ww_tap_unbind <= 0;                      
            end  
        end 
	end 
    
    reg [(pADDR_WIDTH-1):0] rr_counter = 0;
    reg [(pADDR_WIDTH-1):0] rr_temp_addres = 0;
    
    always @(posedge axis_clk) begin
        if ((status == 32'h0000_0002 || status == 32'h0000_0004)|| (status == 32'h0000_0000 && araddr < 12'h020)    &&    ((!ww_tap_unbind) && (!awready_t) && (!wready_t)) && system_ready) begin //判断输出环境 
            if (arvalid && rready && rr_counter == 0) begin
                arready_t <= 1;
                rr_counter <= rr_counter + 1;
                rr_temp_addres <= araddr;
            end 
            else begin 
                arready_t <= 0;
            end 
            
            if (rr_counter == 1) begin 
                if (araddr == 12'h00) begin //查询状态
                    rr_counter <= 3;
                end
                else if (araddr == 12'h10) begin //查询数据长度
                    rr_counter <= 3;
                end 
                else if((rr_temp_addres >= 12'h020) && rr_temp_addres<= ((12'h020+11*4))) begin //查询系数
                    //设置tap_ram
                    tap_EN_t <= 1;
                    tap_A_t <= rr_temp_addres-12'h020;
                    rr_counter <= rr_counter + 1;
                end
                else begin
                    rr_counter <= 0;
                end 
            end 
            
            if (rr_counter == 2) begin
                 rr_counter <= rr_counter + 1;
            end 
            
            if (rr_counter == 3) begin
                if (araddr == 12'h00) begin //查询状态
                    rdata_t <= status;
                    rvalid_t <= 1;
                end
                else if (araddr == 12'h10) begin //查询数据长度
                    rdata_t <= data_length;
                    rvalid_t <= 1;
                end 
                else if((rr_temp_addres >= 12'h020) && rr_temp_addres<= ((12'h020+11*4))) begin //查询系数
                    rdata_t <= tap_Do;
                    rvalid_t <= 1;
                    
                    tap_EN_t <= 0;
                    tap_A_t <= 0;
                end
                rr_counter <= rr_counter + 1;
                
            end 
            
            else begin
                rdata_t <= 0;
                rvalid_t <= 0;
            end 
            
            if (rr_counter == 4) begin
                rr_counter <= 0;
            end 
        end
    end 

	////////////////////////////////////////////////////////idle_end////////////////////////////////////////////////////////
    always @(posedge axis_clk) begin
        if (status == 32'h0000_0004 && system_ready) begin 
            initial_flag <= 1;
        end 
    end    
	
end
endmodule