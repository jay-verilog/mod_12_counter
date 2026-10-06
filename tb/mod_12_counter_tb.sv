// interface
interface mod_12_counter_if
#(
parameter MOD = 12
)
(input clk);

   logic                   rst_n;
   logic [$clog2(MOD)-1:0] data_in;
   logic                   load_en;
   logic                   up_down;
   logic [$clog2(MOD)-1:0] count_out;

   clocking drv_cb @(negedge clk);
      default input #1 output #0;
      output rst_n;
      output data_in;
      output load_en;
      output up_down;
   endclocking 


   clocking mon_cb @(posedge clk);
      default input #0 output #0;
      input rst_n;
      input data_in;
      input load_en;
      input count_out;
      input up_down;
   endclocking

   modport DRV_MD (clocking drv_cb);
   modport MON_MD (clocking mon_cb);

endinterface


// transaction 
class transaction #(parameter MOD = 12); 

   rand logic                   rst_n; 
   rand logic [$clog2(MOD)-1:0] data_in; 
   rand logic                   load_en; 
   rand logic                   up_down; 

   logic [$clog2(MOD)-1:0] count_out; 
   
   constraint weight 
   {
      rst_n   dist {0 := 2, 1 := 8};
      load_en dist {0 := 8, 1 := 2};
   }

   constraint data_in_limit 
   {
      data_in < 12;
   }


   function void display(string name = "Transaction");
      $display("----------- %s ---------", name);
      $display("Reset       = %0d", rst_n);
      $display("Load Enable = %0d", load_en);
      $display("Load Data   = %0d", data_in);
      $display("UpDown      = %0d", up_down);
      $display("Count Out   = %0d", count_out);
   endfunction

endclass


// generation
class generation;
   static int num_txns;
   mailbox #(transaction) gen2drv;

   function new(mailbox #(transaction) gen2drv);
      this.gen2drv = gen2drv;
   endfunction
 
   task run();
      transaction trans_h;
      repeat(num_txns)
      begin
         trans_h = new();
         assert(trans_h.randomize());
         gen2drv.put(trans_h);
      end
   endtask

endclass


// Driver
class driver;
   virtual mod_12_counter_if.DRV_MD drv_if;
   mailbox #(transaction) gen2drv;

   function new(virtual mod_12_counter_if.DRV_MD drv_if,
                mailbox #(transaction) gen2drv);
      this.drv_if  = drv_if;
      this.gen2drv = gen2drv;
   endfunction


   task run();
      transaction trans_h;
      forever
      begin
         gen2drv.get(trans_h);
         @(drv_if.drv_cb);
         drv_if.drv_cb.rst_n   <= trans_h.rst_n;
         drv_if.drv_cb.data_in <= trans_h.data_in;
         drv_if.drv_cb.load_en <= trans_h.load_en;
         drv_if.drv_cb.up_down <= trans_h.up_down;
         trans_h.display("Driver");
      end
   endtask
endclass


// Monitor
class monitor;
   virtual mod_12_counter_if.MON_MD mon_if;
   mailbox #(transaction) mon2rm;
   mailbox #(transaction) mon2sb;


   function new(virtual mod_12_counter_if.MON_MD mon_if,
                mailbox #(transaction) mon2rm,
                mailbox #(transaction) mon2sb);
      this.mon_if = mon_if;
      this.mon2rm = mon2rm;
      this.mon2sb = mon2sb;
   endfunction


   task run();
      transaction trans_h;
      transaction rm_trans_h;
      transaction sb_trans_h;

      forever
      begin
         trans_h    = new();
         rm_trans_h = new();
         sb_trans_h = new();

         @(mon_if.mon_cb);

         trans_h.rst_n     = mon_if.mon_cb.rst_n;
         trans_h.data_in   = mon_if.mon_cb.data_in;
         trans_h.load_en   = mon_if.mon_cb.load_en;
         trans_h.up_down   = mon_if.mon_cb.up_down;
         trans_h.count_out = mon_if.mon_cb.count_out;

         rm_trans_h.rst_n     = trans_h.rst_n;
         rm_trans_h.data_in   = trans_h.data_in;
         rm_trans_h.load_en   = trans_h.load_en;
         rm_trans_h.up_down   = trans_h.up_down;
         rm_trans_h.count_out = trans_h.count_out;

         sb_trans_h.rst_n     = trans_h.rst_n;
         sb_trans_h.data_in   = trans_h.data_in;
         sb_trans_h.load_en   = trans_h.load_en;
         sb_trans_h.up_down   = trans_h.up_down;
         sb_trans_h.count_out = trans_h.count_out;

         mon2rm.put(rm_trans_h);
         mon2sb.put(sb_trans_h);
         trans_h.display("Monitor");
      end
   endtask
endclass


// Reference Model
class reference_model #(parameter MOD = 12);

   mailbox #(transaction) mon2rm;
   mailbox #(transaction) rm2sb;
   transaction trans_h;
   transaction sb_trans_h;

   bit [$clog2(MOD)-1:0] expected_count_out;

   function new(mailbox #(transaction) mon2rm,
                mailbox #(transaction) rm2sb);
      this.mon2rm = mon2rm;
      this.rm2sb  = rm2sb;
      expected_count_out = 0;
   endfunction


   task run();
      forever
      begin
         mon2rm.get(trans_h);

         if(trans_h.rst_n == 1'b0)
         begin
            expected_count_out = 0;
         end

         else if(trans_h.load_en == 1'b1)
         begin
            expected_count_out = trans_h.data_in;
         end

         else if(trans_h.up_down == 1'b1)
         begin
            if(expected_count_out == MOD-1)
            begin
               expected_count_out = 0;
            end

            else
            begin
               expected_count_out++;
            end
         end

         else
         begin
            if(expected_count_out == 0)
            begin
               expected_count_out = MOD-1;
            end

            else
            begin
               expected_count_out--;
            end
         end

         sb_trans_h = new();

         sb_trans_h.rst_n     = trans_h.rst_n;
         sb_trans_h.data_in   = trans_h.data_in;
         sb_trans_h.load_en   = trans_h.load_en;
         sb_trans_h.up_down   = trans_h.up_down;
         sb_trans_h.count_out = expected_count_out;

         rm2sb.put(sb_trans_h);

         $display("----------- Reference Model ---------");
         $display("Reset       = %0d", trans_h.rst_n);
         $display("Load Enable = %0d", trans_h.load_en);
         $display("Load Data   = %0d", trans_h.data_in);
         $display("UpDown      = %0d", trans_h.up_down);
         $display("Count Out   = %0d", sb_trans_h.count_out);
      end
   endtask
endclass


// Scoreboard
class scoreboard;
   mailbox #(transaction) mon2sb;
   mailbox #(transaction) rm2sb;

   transaction expected_h;
   transaction actual_h;

   static int pass  = 0;
   static int fail  = 0;
   static int total = 0;

   // Functional Coverage
   covergroup mod_counter_cg;

      cp_reset : coverpoint actual_h.rst_n
      {
         bins reset    = {0};
         bins no_reset = {1};
      }

      cp_load : coverpoint actual_h.load_en
      {
         bins load_on  = {1};
         bins load_off = {0};
      }

      cp_updown : coverpoint actual_h.up_down
      {
         bins up   = {1};
         bins down = {0};
      }

      cp_data : coverpoint actual_h.data_in
      {
         bins min       = {0};
         bins data_1_3  = {[1:3]};
         bins data_4_7  = {[4:7]};
         bins data_8_10 = {[8:10]};
         bins max       = {11};
      }

      cp_count : coverpoint actual_h.count_out
      {
         bins min_count  = {0};
         bins count_1_3  = {[1:3]};
         bins count_4_7  = {[4:7]};
         bins count_8_10 = {[8:10]};
         bins max_count  = {11};
      }

      load_direction : cross cp_load, cp_updown;
      reset_load : cross cp_reset, cp_load;

   endgroup


   function new(
      mailbox #(transaction) mon2sb,
      mailbox #(transaction) rm2sb
   );

      this.mon2sb = mon2sb;
      this.rm2sb  = rm2sb;
      mod_counter_cg = new();

   endfunction


   task run();

      forever
      begin
         mon2sb.get(actual_h);
         rm2sb.get(expected_h);
         mod_counter_cg.sample();

         if(expected_h.count_out == actual_h.count_out)
         begin
            $display("----------- TEST PASS ---------");
            actual_h.display("Scoreboard");
            pass++;
            total++;
         end

         else
         begin
            $display("----------- TEST FAIL ---------");
            actual_h.display("Scoreboard");
            $display(
               "Actual Count = %0d Expected Count = %0d",
               actual_h.count_out,
               expected_h.count_out
            );
            fail++;
            total++;
         end
      end
   endtask

   function void pass_fail_condition();
      $display("-------------------------------------");
      $display("Pass  = %0d", pass);
      $display("Fail  = %0d", fail);
      $display("Total = %0d", total);
      $display("-------------------------------------");
   endfunction

   function void report_coverage();
      $display("\n======================================");
      $display("       FUNCTIONAL COVERAGE");
      $display("======================================");
      $display(
         "Coverage = %0.2f %%",
         mod_counter_cg.get_coverage()
      );
      $display("======================================\n");
   endfunction
endclass


// Environment
class environment; 
   generation      gen;
   driver          drv;
   monitor         mon;
   reference_model rm;
   scoreboard      sb;
    
   virtual mod_12_counter_if.DRV_MD env_drv_if;
   virtual mod_12_counter_if.MON_MD env_mon_if;

   mailbox #(transaction) gen2drv;
   mailbox #(transaction) mon2rm;
   mailbox #(transaction) mon2sb;
   mailbox #(transaction) rm2sb;   

   function new(virtual mod_12_counter_if.DRV_MD env_drv_if,
                virtual mod_12_counter_if.MON_MD env_mon_if);

      this.env_drv_if = env_drv_if;
      this.env_mon_if = env_mon_if;
    
      gen2drv = new();
      mon2rm  = new();
      mon2sb  = new();
      rm2sb   = new();

      gen = new(gen2drv);
      drv = new(env_drv_if, gen2drv);
      mon = new(env_mon_if, mon2rm, mon2sb);
      rm  = new(mon2rm, rm2sb);
      sb  = new(mon2sb, rm2sb);
   endfunction 

   task run();
      fork
         gen.run();
         drv.run();
         mon.run();
         rm.run();
         sb.run();
      join_none
   endtask
endclass 


// Test
class test;
   virtual mod_12_counter_if.DRV_MD test_drv_if;
   virtual mod_12_counter_if.MON_MD test_mon_if;
   environment env;
   int num_txns;

   function new(virtual mod_12_counter_if.DRV_MD test_drv_if,
                virtual mod_12_counter_if.MON_MD test_mon_if,
                int num_txns);
      this.test_drv_if = test_drv_if;
      this.test_mon_if = test_mon_if;
      this.num_txns    = num_txns;
   endfunction

   task build();
      env = new(test_drv_if, test_mon_if);
      env.gen.num_txns = num_txns;
   endtask

   task run();
      env.run();
      wait(env.sb.total == num_txns);
   endtask


   task report();
      env.sb.pass_fail_condition();
      env.sb.report_coverage();
   endtask
endclass


module mod_12_counter_tb;
   logic clk;
   mod_12_counter_if top_if(clk);

   mod_12_counter dut
   (
   .clk       (clk),
   .rst_n     (top_if.rst_n),
   .data_in   (top_if.data_in),
   .load_en   (top_if.load_en),
   .up_down   (top_if.up_down),
   .count_out (top_if.count_out)
   );

   initial
   begin
      clk = 1'b0;
      forever #5 clk = ~clk;
   end

   test t_h;

   initial
   begin
      top_if.rst_n   = 0;
      top_if.data_in = 0;
      top_if.load_en = 0;
      top_if.up_down = 0;

      #15;

      t_h = new(top_if.DRV_MD,top_if.MON_MD,1000);

      t_h.build();
      t_h.run();
      t_h.report();
      $finish();
   end

   initial
   begin
      $dumpfile("wave.vcd");
      $dumpvars(0, mod_12_counter_tb);
   end

endmodule
