include "../../../../common/commons.dfy"

include "../../common/dvc_block_proposer_instrumented.dfy"
include "../../../bn_axioms.dfy"
include "../../../rs_axioms.dfy"

include "../../../../specs/consensus/consensus.dfy"
include "../../../../specs/network/network.dfy"
include "../../../../specs/dv/dv_block_proposer.dfy"

include "invs_fnc_1.dfy"
include "invs_fnc_2.dfy"
include "invs_dv_next_1.dfy"
include "invs_dv_next_2.dfy"
include "invs_dv_next_3.dfy"
include "invs_dv_next_4.dfy"
include "invs_dv_next_5.dfy"

include "../inv.dfy"
include "../ind_inv.dfy"

include "proofs_intermediate_steps.dfy"

module Ind_Inv_DV_Next
{
    import opened Types
    
    import opened Common_Functions
    import opened Consensus
    import opened Network_Spec
    import opened Block_DVC
    import opened Consensus_Engine
    import opened BN_Axioms
    import opened RS_Axioms
    import opened Block_Inv_With_Empty_Initial_Block_Slashing_DB
    import opened Block_Ind_Inv_With_Empty_Initial_Block_Slashing_DB
    import opened Block_DV    
    import opened Fnc_Invs_1
    import opened Fnc_Invs_2
    import opened Invs_DV_Next_1
    import opened Invs_DV_Next_2
    import opened Invs_DV_Next_3
    import opened Invs_DV_Next_4
    import opened Invs_DV_Next_5
    import opened Proofs_Intermediate_Steps
    import opened DV_Block_Proposer_Assumptions
    

    lemma lem_ind_inv_dv_next_invs_group_1(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_1(dv')
    {    
        lem_inv_all_honest_nodes_is_quorum_dv_next(dv, e, dv');
        lem_inv_nodes_in_consensus_instances_are_in_dv_dv_next(dv, e, dv');
        lem_inv_only_dv_construct_complete_signing_functions_dv_next(dv, e, dv');
        lem_inv_current_proposer_duty_is_rcvd_duty_dv_next(dv, e, dv');
        lem_inv_latest_served_duty_is_rcvd_duty_dv_next(dv, e, dv');        
    }

    lemma lem_ind_inv_dv_next_invs_group_2(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_2(dv')
    {
        lem_inv_none_latest_proposer_duty_implies_none_current_proposer_duty_dv_next(dv, e, dv');
        lem_inv_current_proposer_duty_is_either_none_or_latest_proposer_duty_dv_next(dv, e, dv');
        lem_inv_available_current_proposer_duty_is_latest_proposer_duty_dv_next(dv, e, dv');        
    }

    lemma lem_ind_inv_dv_next_invs_group_3(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_3(dv')
    {
        lem_inv_no_duplicated_proposer_duties_in_dv_seq_dv_next(dv, e, dv');
        lem_inv_every_proposer_duty_before_dv_index_next_proposer_duty_to_be_served_was_delivered_dv_next(dv, e, dv');        
        lem_inv_dvc_has_no_active_consensus_instances_if_latest_proposer_duty_is_none_dv_next(dv, e, dv');                        
    }

    lemma lem_ind_inv_dv_next_invs_group_4(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_4(dv')
    {
        lem_inv_slots_of_active_consensus_instances_are_not_higher_than_slot_of_latest_proposer_duty_dv_next(dv, e, dv');                
        lem_inv_dvc_only_joins_consensus_instances_for_which_it_has_received_corresponding_proposer_duties_dv_next(dv, e, dv');    
        lem_inv_consensus_instance_indexed_k_is_for_rcvd_duty_at_slot_k_dv_next(dv, e, dv');    
        lem_inv_rcvd_proposer_duty_is_from_dv_seq_for_proposer_duties_dv_next(dv, e, dv');    
    }

    lemma lem_ind_inv_dv_next_invs_group_5(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_5(dv')
    {
        lem_inv_slashing_db_hist_keeps_track_of_all_rcvd_proposer_duties_dv_next(dv, e, dv');    
        lem_inv_exists_db_in_slashing_db_hist_and_proposer_duty_and_randao_reveal_for_every_validity_predicate_dv_next(dv, e, dv');  
        lem_inv_current_validity_predicate_for_slot_k_is_stored_in_slashing_db_hist_k_dv_next(dv, e, dv');          
    }

    lemma lem_ind_inv_dv_next_invs_group_6(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_6(dv')
    {       
        lem_inv_every_db_in_slashing_db_hist_is_subset_of_block_slashing_db_dv_next(dv, e, dv');  
        lem_inv_active_consensus_instances_are_tracked_in_slashing_db_hist_dv_next(dv, e, dv');  
    }

    lemma lem_ind_inv_dv_next_invs_group_7(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_7(dv')
    {               
        lem_inv_all_in_transit_messages_were_sent_dv_next(dv, e, dv');  
        lem_inv_rcvd_block_shares_are_from_sent_messages_dv_next(dv, e, dv');  
        lem_inv_same_node_status_between_dv_and_ci_ind_inv(dv);
        assert  inv_same_node_status_between_dv_and_ci(dv);
        lem_inv_slots_for_sent_validity_predicates_are_stored_in_slashing_db_hist(dv, e, dv');
    }

    lemma lem_ind_inv_implies_intermediate_steps_helper_1(dv: BlockDVState)
    requires ind_inv(dv)
    ensures inv_proposer_duty_in_next_delivery_is_higher_than_latest_served_proposer_duty(dv)
    ensures inv_proposer_duty_in_next_delivery_is_not_lower_than_rcvd_proposer_duties(dv)
    {    
        lem_inv_proposer_duty_in_next_delivery_is_higher_than_latest_served_proposer_duty_ind_inv(dv);
        lem_inv_proposer_duty_in_next_delivery_is_not_lower_than_rcvd_proposer_duties_ind_inv(dv);
    }

    lemma lem_ind_inv_implies_intermediate_steps_helper_2(dv: BlockDVState)
    requires ind_inv(dv)  
    ensures inv_sent_vp_is_based_on_existing_slashing_db_and_rcvd_proposer_duty_and_randao_reveal(dv)
    ensures inv_active_consensus_instances_imply_delivery_of_proposer_duties(dv)   
    ensures inv_same_node_status_between_dv_and_ci(dv)    
    ensures assump_construction_of_complete_signed_block(
                dv.construct_complete_signed_block,
                dv.dv_pubkey,
                dv.all_nodes
            )  
    {    
        lem_inv_sent_vp_is_based_on_existing_slashing_db_and_rcvd_proposer_duty_and_randao_reveal_ind_inv(dv);
        lem_inv_active_consensus_instances_imply_delivery_of_proposer_duties_ind_inv(dv);
        lem_inv_same_node_status_between_dv_and_ci_ind_inv(dv);      
        lem_assump_construction_of_complete_signed_block(dv);       
    }

    lemma lem_ind_inv_implies_intermediate_steps_helper_3(dv: BlockDVState)
    requires ind_inv(dv)  
    ensures inv_seq_of_proposer_duties_is_ordered(dv)
    ensures inv_active_consensus_instances_are_tracked_in_slashing_db_hist(dv)
    ensures inv_available_current_proposer_duty_is_latest_proposer_duty(dv)
    ensures inv_rcvd_block_shares_are_in_all_sent_messages(dv)
    {            
        lem_inv_available_current_proposer_duty_is_latest_proposer_duty(dv);
        lem_inv_rcvd_block_shares_are_from_sent_messages_inv_rcvd_block_shares_are_in_all_sent_messages(dv);
    }

    lemma lem_ind_inv_implies_intermediate_steps_helper_4(dv: BlockDVState)
    requires ind_inv(dv)  
    ensures lem_inv_exists_honest_dvc_that_sent_block_share_for_submitted_block_new_precond(dv)    
    ensures inv_block_of_all_created_blocks_is_set_of_decided_values(dv)
    {   
        lem_ind_inv_implies_intermediate_steps_helper_1(dv);
        lem_ind_inv_implies_intermediate_steps_helper_2(dv);
        lem_ind_inv_implies_intermediate_steps_helper_3(dv);   
        lem_inv_block_of_all_created_blocks_is_set_of_decided_values_dv_next(dv);
    }

    lemma lem_ind_inv_implies_intermediate_steps(dv: BlockDVState)
    requires ind_inv(dv)
    ensures inv_proposer_duty_in_next_delivery_is_higher_than_latest_served_proposer_duty(dv)
    ensures inv_proposer_duty_in_next_delivery_is_not_lower_than_rcvd_proposer_duties(dv)
    ensures inv_sent_vp_is_based_on_existing_slashing_db_and_rcvd_proposer_duty_and_randao_reveal(dv)
    ensures inv_active_consensus_instances_imply_delivery_of_proposer_duties(dv)   
    ensures inv_same_node_status_between_dv_and_ci(dv)    
    ensures assump_construction_of_complete_signed_block(
                dv.construct_complete_signed_block,
                dv.dv_pubkey,
                dv.all_nodes
            )    
    ensures inv_seq_of_proposer_duties_is_ordered(dv)     
    ensures inv_active_consensus_instances_are_tracked_in_slashing_db_hist(dv)
    ensures inv_available_current_proposer_duty_is_latest_proposer_duty(dv)
    ensures inv_rcvd_block_shares_are_in_all_sent_messages(dv)
    ensures lem_inv_exists_honest_dvc_that_sent_block_share_for_submitted_block_new_precond(dv)
    ensures inv_block_of_all_created_blocks_is_set_of_decided_values(dv)
    {   
        lem_ind_inv_implies_intermediate_steps_helper_1(dv); 
        lem_ind_inv_implies_intermediate_steps_helper_2(dv);
        lem_ind_inv_implies_intermediate_steps_helper_3(dv);
        lem_ind_inv_implies_intermediate_steps_helper_4(dv);
        lem_inv_sent_vp_is_based_on_existing_slashing_db_and_rcvd_proposer_duty_and_randao_reveal_ind_inv(dv);
        lem_inv_block_of_all_created_blocks_is_set_of_decided_values_dv_next(dv);
    }
   
    lemma lem_ind_inv_dv_next_invs_group_8(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_8(dv')
    {
        lem_inv_exists_honest_dvc_that_sent_block_share_for_submitted_block_dv_next(dv, e, dv');
        lem_inv_decided_values_of_consensus_instances_are_decided_by_quorum_dv_next(dv, e, dv');  
        lem_inv_sent_validity_predicate_is_based_on_rcvd_proposer_duty_and_slashing_db_and_randao_reveal_for_dv_dv_next(dv, e, dv');
        lem_inv_sent_validity_predicate_is_based_on_rcvd_proposer_duty_and_slashing_db_and_randao_reveal_dv_next(dv, e, dv');        
    }

    lemma lem_ind_inv_dv_next_invs_group_9(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_9(dv')
    {
        lem_inv_decided_value_of_consensus_instance_for_slot_k_is_for_slot_k_dv_next(dv, e, dv');
        lem_inv_all_in_transit_messages_were_sent_dv_next(dv, e, dv');
        lem_inv_all_in_transit_messages_were_sent_inv_in_transit_messages_are_in_allMessagesSent(dv');
        lem_inv_block_shares_to_broadcast_are_sent_messages_dv_next(dv, e, dv');        
    }

    lemma lem_ind_inv_dv_next_invs_group_10(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_10(dv')
    {        
        lem_inv_available_latest_proposer_duty_is_from_dv_seq_of_proposer_duties_dv_next(dv, e, dv');
        lem_ind_inv_implies_intermediate_steps(dv);        
        lem_inv_available_current_proposer_duty_is_from_dv_seq_of_proposer_duties_dv_next(dv, e, dv');        
        lem_inv_blocks_of_in_transit_block_shares_are_decided_values_dv_next(dv, e, dv');
        lem_inv_exists_proposer_duty_in_dv_seq_of_proposer_duties_for_every_slot_in_slashing_db_hist_dv_next(dv, e, dv');
    }
    
    lemma lem_ind_inv_dv_next_invs_group_11(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_11(dv')
    {
        lem_ind_inv_implies_intermediate_steps_helper_4(dv);
        lem_inv_future_decided_blocks_known_by_dvc_are_decisions_of_quorums(dv, e, dv');
        lem_inv_slots_in_future_decided_beacon_blocks_are_correct_dv_next(dv, e, dv');    
        lem_inv_none_latest_proposer_duty_and_empty_set_of_rcvd_proposer_duties_dv_next(dv, e, dv');   
        lem_inv_unique_rcvd_proposer_duty_per_slot_dv_next(dv, e, dv');     
    }

    lemma lem_ind_inv_dv_next_invs_group_12(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_12(dv')
    {
        lem_ind_inv_implies_intermediate_steps_helper_4(dv);
        lem_inv_consensus_instance_condition_for_safety_is_true_dv_next(dv, e, dv');   
        lem_inv_no_rcvd_proposer_duty_is_higher_than_latest_proposer_duty_dv_next(dv, e, dv');  
        lem_inv_sent_validity_predicate_only_for_slots_stored_in_slashing_db_hist(dv, e, dv');
        lem_inv_all_validity_predicates_are_stored_in_slashing_db_hist_dv_next(dv, e, dv');
    }

    lemma lem_ind_inv_dv_next_invs_group_13(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_13(dv')
    {
        lem_inv_unchanged_dvc_rs_pubkey_dv_next(dv, e, dv');
        lem_inv_all_created_signed_beacon_blocks_are_valid_dv_next(dv, e, dv');
        lem_inv_complete_signed_block_is_created_based_on_shares_from_quorum_dv_next(dv, e, dv');
        lem_inv_exists_honest_dvc_as_witness_for_every_decided_beacon_block_dv_next(dv, e, dv');
    }

    lemma lem_ind_inv_dv_next_invs_group_14(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_14(dv')
    {   
        lem_inv_seq_of_proposer_duties_is_ordered_dv_next(dv, e, dv');
        lem_inv_block_shares_to_broadcast_are_tracked_in_block_slashing_db_dv_next(dv, e, dv');
        lem_inv_sent_block_shares_have_corresponding_stored_slashing_db_blocks_dv_next(dv, e, dv');
        lem_inv_slots_of_consensus_instances_are_up_to_slot_of_latest_proposer_duty_dv_next(dv, e, dv');
        lem_inv_db_of_vp_contains_all_beacon_block_of_sent_block_shares_with_lower_slots_dv_next(dv, e, dv');        
    }

    lemma lem_ind_inv_dv_next_invs_group_15(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_15(dv')
    {   
        lem_inv_none_latest_proposer_duty_implies_emply_block_slashing_db_dv_next(dv, e, dv');
        lem_inv_slots_in_slashing_db_is_not_higher_than_slot_of_latest_proposer_duty_dv_next(dv, e, dv');
        
        lem_inv_exists_honest_dvc_that_sent_block_share_for_submitted_block_dv_next(dv, e, dv');
        lem_inv_blocks_of_in_transit_block_shares_are_decided_values_dv_next(dv, e, dv');
        lem_inv_all_created_signed_beacon_blocks_are_valid_dv_next(dv, e, dv');
        lem_inv_block_of_all_created_blocks_is_set_of_decided_values_dv_next(dv');
        lem_inv_at_most_one_submitted_signed_beacon_block_with_available_signing_root_for_every_slot_dv_next(dv');

        lem_inv_none_latest_slashing_db_block_implies_emply_block_slashing_db_dv_next(dv, e, dv');
        lem_inv_slots_in_slashing_db_are_not_higher_than_slot_of_latest_slashing_db_block_dv_next(dv, e, dv');
        lem_inv_slots_in_slashing_db_are_not_higher_than_slot_of_latest_slashing_db_block_dv_next(dv, e, dv');
        lem_inv_none_latest_slashing_db_block_implies_emply_block_slashing_db_dv_next(dv, e, dv');
    }
    
    lemma lem_ind_inv_dv_next_ind_inv_helper_1(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_1(dv')
    ensures invs_group_2(dv')
    ensures invs_group_3(dv')
    {
        lem_ind_inv_dv_next_invs_group_1(dv, e, dv');
        lem_ind_inv_dv_next_invs_group_2(dv, e, dv');
        lem_ind_inv_dv_next_invs_group_3(dv, e, dv');
    }

    lemma lem_ind_inv_dv_next_ind_inv_helper_2(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)  
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)    
    ensures invs_group_4(dv')
    ensures invs_group_5(dv')
    ensures invs_group_6(dv')
    ensures invs_group_7(dv') 
    ensures invs_group_8(dv')
    {
        lem_ind_inv_dv_next_invs_group_4(dv, e, dv');
        lem_ind_inv_dv_next_invs_group_5(dv, e, dv');
        lem_ind_inv_dv_next_invs_group_6(dv, e, dv');
        lem_ind_inv_dv_next_invs_group_7(dv, e, dv');
        lem_ind_inv_dv_next_invs_group_8(dv, e, dv');
    }

    lemma lem_ind_inv_dv_next_ind_inv_helper_3(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_9(dv')
    ensures invs_group_10(dv')
    ensures invs_group_11(dv')
    {        
        lem_ind_inv_dv_next_invs_group_9(dv, e, dv');       
        lem_ind_inv_dv_next_invs_group_10(dv, e, dv');  
        lem_ind_inv_dv_next_invs_group_11(dv, e, dv');                                     
    }

    lemma lem_ind_inv_dv_next_ind_inv_helper_4(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)
    ensures invs_group_12(dv')   
    ensures invs_group_13(dv')            
    {        
        lem_ind_inv_dv_next_invs_group_12(dv, e, dv');                              
        lem_ind_inv_dv_next_invs_group_13(dv, e, dv');             
    }

    lemma lem_ind_inv_dv_next_ind_inv_helper_5(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)    
    ensures invs_group_14(dv')
    ensures invs_group_15(dv')
    {        
        lem_ind_inv_dv_next_invs_group_14(dv, e, dv');                              
        lem_ind_inv_dv_next_invs_group_15(dv, e, dv');                              
    }

    lemma lem_ind_inv_dv_next_ind_inv_helper_a(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv) 
    ensures invs_group_1(dv')
    ensures invs_group_2(dv')
    ensures invs_group_3(dv')
    ensures invs_group_4(dv')
    ensures invs_group_5(dv')
    ensures invs_group_6(dv')
    ensures invs_group_7(dv')
    ensures invs_group_8(dv')    
    {
        lem_ind_inv_dv_next_ind_inv_helper_1(dv, e, dv');                          
        lem_ind_inv_dv_next_ind_inv_helper_2(dv, e, dv');    
    }

    lemma lem_ind_inv_dv_next_ind_inv_helper_b(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv) 
    ensures invs_group_9(dv')    
    ensures invs_group_10(dv')    
    ensures invs_group_11(dv')    
    ensures invs_group_12(dv')    
    ensures invs_group_13(dv')    
    ensures invs_group_14(dv')
    ensures invs_group_15(dv')
    {
        lem_ind_inv_dv_next_ind_inv_helper_3(dv, e, dv');   
        lem_ind_inv_dv_next_ind_inv_helper_4(dv, e, dv');    
        lem_ind_inv_dv_next_ind_inv_helper_5(dv, e, dv');    
    }

    lemma lem_ind_inv_dv_next_ind_inv_helper(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv) 
    ensures invs_group_1(dv')
    ensures invs_group_2(dv')   
    ensures invs_group_3(dv')   
    ensures invs_group_4(dv')   
    ensures invs_group_5(dv')   
    ensures invs_group_6(dv')
    ensures invs_group_7(dv')
    ensures invs_group_8(dv')
    ensures invs_group_9(dv')    
    ensures invs_group_10(dv')    
    ensures invs_group_11(dv')    
    ensures invs_group_12(dv')    
    ensures invs_group_13(dv')    
    ensures invs_group_14(dv')    
    ensures invs_group_15(dv')    
    {   
        lem_ind_inv_dv_next_ind_inv_helper_a(dv, e, dv');
        lem_ind_inv_dv_next_ind_inv_helper_b(dv, e, dv');                
    }

    lemma lem_ind_inv_dv_next_ind_inv(dv: BlockDVState, e: DVBlockEvent, dv': BlockDVState)       
    requires Block_DV.next_event_preconditions(dv, e)
    requires Block_DV.next_event(dv, e, dv')  
    requires ind_inv(dv)    
    ensures ind_inv(dv')    
    {   
        lem_ind_inv_dv_next_ind_inv_helper(dv, e, dv');                                  
    }

    lemma lem_ind_inv_dv_ind_inv_next_preconditions(dv: BlockDVState, dv': BlockDVState)       
    requires Block_DV.next_preconditions(dv)
    requires Block_DV.next(dv, dv')  
    requires ind_inv(dv)    
    ensures ind_inv(dv')  
    ensures Block_DV.next_preconditions(dv')
    {
        var e :|
            && preconditions_for_HonestNodeTakingStep(dv, e)
            && next_event(dv, e, dv');

        lem_ind_inv_dv_next_ind_inv(dv, e, dv');
        lem_next_preconditions(dv');
    } 

    lemma lem_next_preconditions(
        s: BlockDVState
    )
    requires ind_inv(s)
    ensures  next_preconditions(s)                
    {
        forall event | preconditions_for_HonestNodeTakingStep(s, event)
        ensures next_event_preconditions(s, event);
        {
            if event.HonestNodeTakingStep?
            {

            }
        }

    }     
}