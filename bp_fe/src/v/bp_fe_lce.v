/**
 *
 * Name:
 *   bp_fe_lce.v
 *
 * Description:
 *   To	be updated
 *
 * Notes:
 *
 */


module bp_fe_lce
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_be_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_fe_icache_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_cfg_link_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_icache_p, dword_width_p, cce_block_width_icache_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, lce_sets_icache_p, lce_assoc_icache_p, dword_width_p, cce_block_width_icache_p)

   , localparam way_id_width_lp=`BSG_SAFE_CLOG2(lce_assoc_icache_p)
   , localparam block_size_in_words_lp=lce_assoc_icache_p
   , localparam data_mask_width_lp=(dword_width_p>>3)
   , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(dword_width_p>>3)
   , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam index_width_lp=`BSG_SAFE_CLOG2(lce_sets_icache_p)
   , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
   , localparam tag_width_lp=(paddr_width_p-block_offset_width_lp-index_width_lp)
   
   , localparam bp_be_dcache_stat_width_lp = `bp_be_dcache_stat_info_width(lce_assoc_icache_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
  )
  (
    input                                                        clk_i
    , input                                                      reset_i

    , input [cfg_bus_width_lp-1:0]                               cfg_bus_i

    , input [cache_req_width_lp-1:0]                             cache_req_i
    , input                                                      cache_req_v_i
    , output logic                                               cache_req_ready_o
    , input [cache_req_metadata_width_lp-1:0]                    cache_req_metadata_i
    , input                                                      cache_req_metadata_v_i

    , output logic                                               cache_req_complete_o

    , output logic [cache_data_mem_pkt_width_lp-1:0]             data_mem_pkt_o
    , output logic                                               data_mem_pkt_v_o
    , input                                                      data_mem_pkt_ready_i
    , input  [cce_block_width_icache_p-1:0]                             data_mem_i

    , output logic [cache_tag_mem_pkt_width_lp-1:0]              tag_mem_pkt_o
    , output logic                                               tag_mem_pkt_v_o
    , input                                                      tag_mem_pkt_ready_i
    , input [tag_width_lp-1:0]                                   tag_mem_i
       
    , output logic [cache_stat_mem_pkt_width_lp-1:0]             stat_mem_pkt_o
    , output logic                                               stat_mem_pkt_v_o
    , input                                                      stat_mem_pkt_ready_i
    , input  [bp_be_dcache_stat_width_lp-1:0]                    stat_mem_i
      
    // LCE-CCE interface 
    , output logic [lce_cce_req_width_lp-1:0] lce_req_o
    , output logic lce_req_v_o
    , input lce_req_ready_i

    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_ready_i

    , input [lce_cmd_width_lp-1:0] lce_cmd_i
    , input lce_cmd_v_i
    , output logic lce_cmd_yumi_o

    , output logic [lce_cmd_width_lp-1:0] lce_cmd_o
    , output logic lce_cmd_v_o
    , input lce_cmd_ready_i
  );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_icache_p, dword_width_p, cce_block_width_icache_p);
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, lce_sets_icache_p, lce_assoc_icache_p, dword_width_p, cce_block_width_icache_p);

  bp_cfg_bus_s cfg_bus_cast_i;

  bp_lce_cce_req_s lce_req;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cmd_s lce_cmd;
  bp_lce_cmd_s lce_cmd_out;

  bp_cache_data_mem_pkt_s data_mem_pkt;
  bp_cache_tag_mem_pkt_s tag_mem_pkt;
  bp_cache_stat_mem_pkt_s stat_mem_pkt;

  assign cfg_bus_cast_i = cfg_bus_i;

  assign lce_req_o           = lce_req;
  assign lce_resp_o          = lce_resp;
  assign lce_cmd          = lce_cmd_i;
  assign lce_cmd_o    = lce_cmd_out;

  assign data_mem_pkt_o = data_mem_pkt;
  assign tag_mem_pkt_o  = tag_mem_pkt;
  assign stat_mem_pkt_o = stat_mem_pkt;

  // lce_REQ
  bp_lce_cce_resp_s lce_req_lce_resp_lo;
  logic cce_data_received;
  logic uncached_data_received;
  logic set_tag_received;
  logic set_tag_wakeup_received;
  logic lce_req_lce_resp_v_lo;
  logic lce_req_lce_resp_yumi_li;
  logic [paddr_width_p-1:0] miss_addr_lo;
  
  logic lce_ready_lo;
  logic coherence_blocked_li;
  
  assign coherence_blocked_li = lce_cmd_v_i & ~lce_cmd_yumi_o; 
  wire cmd_ready = (cfg_bus_cast_i.icache_mode == e_lce_mode_uncached) ? 1'b1 : lce_ready_lo;
  
  bp_fe_lce_req #(.bp_params_p(bp_params_p))
    lce_req_inst (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.lce_id_i(cfg_bus_cast_i.icache_id)

    ,.cache_req_i(cache_req_i)
    ,.cache_req_v_i(cache_req_v_i)
    ,.cache_req_ready_o(cache_req_ready_o)
    ,.cache_req_metadata_i(cache_req_metadata_i)
    ,.cache_req_metadata_v_i(cache_req_metadata_v_i)

    ,.miss_addr_o(miss_addr_lo)

    ,.coherence_blocked_i(coherence_blocked_li)
    ,.cmd_ready_i(cmd_ready)

    ,.cce_data_received_i(cce_data_received)
    ,.uncached_data_received_i(uncached_data_received)
    ,.set_tag_received_i(set_tag_received)
    ,.set_tag_wakeup_received_i(set_tag_wakeup_received)

    ,.lce_req_o(lce_req)
    ,.lce_req_v_o(lce_req_v_o)
    ,.lce_req_ready_i(lce_req_ready_i)

    ,.lce_resp_o(lce_req_lce_resp_lo)
    ,.lce_resp_v_o(lce_req_lce_resp_v_lo)
    ,.lce_resp_yumi_i(lce_req_lce_resp_yumi_li)
  );
  
  bp_lce_cce_resp_s lce_cmd_lce_resp_lo;
  logic lce_cmd_lce_resp_v_lo;
  logic lce_cmd_lce_resp_yumi_li;

  bp_fe_lce_cmd #(.bp_params_p(bp_params_p))
    lce_cmd_inst (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_id_i(cfg_bus_cast_i.icache_id)
    ,.miss_addr_i(miss_addr_lo)

    ,.lce_ready_o(lce_ready_lo)
    ,.set_tag_received_o(set_tag_received)
    ,.set_tag_wakeup_received_o(set_tag_wakeup_received)
    ,.cce_data_received_o(cce_data_received)
    ,.uncached_data_received_o(uncached_data_received)
    
    ,.cache_req_complete_o(cache_req_complete_o)

    ,.data_mem_pkt_o(data_mem_pkt)
    ,.data_mem_pkt_v_o(data_mem_pkt_v_o)
    ,.data_mem_pkt_ready_i(data_mem_pkt_ready_i)
    ,.data_mem_i(data_mem_i)

    ,.tag_mem_pkt_o(tag_mem_pkt)
    ,.tag_mem_pkt_v_o(tag_mem_pkt_v_o)
    ,.tag_mem_pkt_ready_i(tag_mem_pkt_ready_i)
    ,.tag_mem_i(tag_mem_i)    

    ,.stat_mem_pkt_v_o(stat_mem_pkt_v_o)
    ,.stat_mem_pkt_o(stat_mem_pkt)
    ,.stat_mem_pkt_ready_i(stat_mem_pkt_ready_i)
    ,.stat_mem_i(stat_mem_i)

    ,.lce_cmd_i(lce_cmd)
    ,.lce_cmd_v_i(lce_cmd_v_i)
    ,.lce_cmd_yumi_o(lce_cmd_yumi_o)

    ,.lce_resp_o(lce_cmd_lce_resp_lo)
    ,.lce_resp_v_o(lce_cmd_lce_resp_v_lo)
    ,.lce_resp_yumi_i(lce_cmd_lce_resp_yumi_li)

    ,.lce_cmd_o(lce_cmd_out)
    ,.lce_cmd_v_o(lce_cmd_v_o)
    ,.lce_cmd_ready_i(lce_cmd_ready_i)
  );
 
  // lce_RESP arbiter
  // (transfer from lce_req) vs (sync ack or invalidate ack from lce_cmd)
 
  always_comb begin
    lce_req_lce_resp_yumi_li = 1'b0; 
    lce_cmd_lce_resp_yumi_li = 1'b0; 

    if (lce_req_lce_resp_v_lo) begin
      lce_resp_v_o = 1'b1;
      lce_resp = lce_req_lce_resp_lo;
      lce_req_lce_resp_yumi_li = lce_resp_ready_i;
    end
    else begin
      lce_resp_v_o = lce_cmd_lce_resp_v_lo;
      lce_resp = lce_cmd_lce_resp_lo;
      lce_cmd_lce_resp_yumi_li = lce_cmd_lce_resp_v_lo & lce_resp_ready_i;
    end
  end

  endmodule
