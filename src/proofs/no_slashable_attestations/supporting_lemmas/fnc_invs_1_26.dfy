include "../../../common/commons.dfy"
include "../common/attestation_creation_instrumented.dfy"
include "../../../specs/consensus/consensus.dfy"
include "../../../specs/network/network.dfy"
include "../../../specs/dv/dv_attestation_creation.dfy"
include "inv.dfy"
include "../../common/helper_sets_lemmas.dfy"
include "../common/common_proofs.dfy"
include "../common/dvc_spec_axioms.dfy"

module Fnc_Invs_1_26
{
    import opened Types 
    import opened CommonFunctions
    import opened ConsensusSpec
    import opened NetworkSpec
    import opened DVC_Spec
    import opened DV
    import opened Att_Inv_With_Empty_Initial_Attestation_Slashing_DB
    import opened Helper_Sets_Lemmas
    import opened Common_Proofs
    import opened DVC_Spec_Axioms
    
    
    lemma lemma_inv4_f_serve_attestation_duty(
        dvc: DVCState,
        attestation_duty: AttestationDuty,
        dvc': DVCState
    )  
    requires f_serve_attestation_duty.requires(dvc, attestation_duty)
    requires dvc' == f_serve_attestation_duty(dvc, attestation_duty).state
    ensures dvc'.all_rcvd_duties == dvc.all_rcvd_duties + {attestation_duty}    
    {
        var dvc_mod := dvc.(
                attestation_duties_queue := dvc.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := dvc.all_rcvd_duties + {attestation_duty}
            );        

        lemma_inv4_f_check_for_next_queued_duty(dvc_mod, dvc');        
    }

    lemma lemma_inv4_f_check_for_next_queued_duty(
        dvc: DVCState,
        dvc': DVCState
    )
    requires f_check_for_next_queued_duty.requires(dvc)
    requires dvc' == f_check_for_next_queued_duty(dvc).state
    ensures dvc'.all_rcvd_duties == dvc.all_rcvd_duties
    decreases dvc.attestation_duties_queue
    {
        if  && dvc.attestation_duties_queue != [] 
            && (
                || dvc.attestation_duties_queue[0].slot in dvc.future_att_consensus_instances_already_decided
                || !dvc.current_attestation_duty.isPresent()
            )    
        {            
                if dvc.attestation_duties_queue[0].slot in dvc.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := dvc.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(dvc.attestation_slashing_db, dvc.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var dvc_mod := dvc.(
                        attestation_duties_queue := dvc.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := dvc.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            dvc.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    lemma_inv4_f_check_for_next_queued_duty(dvc_mod, dvc');
                }
                else
                { 
                    var dvc_mod := dvc.(
                        attestation_duties_queue := dvc.attestation_duties_queue[1..]
                    );         
                    lemma_inv4_f_start_next_duty(dvc_mod, dvc.attestation_duties_queue[0], dvc');
                }
        }
        else
        { 
            assert dvc'.all_rcvd_duties == dvc.all_rcvd_duties;
        }
    }

    lemma lemma_inv4_f_start_next_duty(dvc: DVCState, attestation_duty: AttestationDuty, dvc': DVCState)
    requires f_start_next_duty.requires(dvc, attestation_duty)
    requires dvc' == f_start_next_duty(dvc, attestation_duty).state
    ensures dvc'.all_rcvd_duties == dvc.all_rcvd_duties        
    {  
        assert dvc'.all_rcvd_duties == dvc.all_rcvd_duties;
    }  

    lemma lemma_inv4_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state 
    ensures process'.all_rcvd_duties == process.all_rcvd_duties
    {
        
        if  && process.current_attestation_duty.isPresent()
            && id == process.current_attestation_duty.safe_get().slot
        {
            var local_current_attestation_duty := process.current_attestation_duty.safe_get();
            var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

            var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
            var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
            var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
            var attestation_with_signature_share := AttestationShare(
                    aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                    data := decided_attestation_data, 
                    signature := attestation_signature_share
                ); 

            var process_mod := 
                process.(
                    current_attestation_duty := None,
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                    attestation_slashing_db := attestation_slashing_db,
                    attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                        process.attestation_consensus_engine_state,
                        attestation_slashing_db
                    )
                );

            var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process_mod);
            
            lemma_inv4_f_check_for_next_queued_duty(process_mod, ret_check_for_next_queued_duty.state);

            assert process' == ret_check_for_next_queued_duty.state;
        } 
    }  


    lemma lemma_inv4_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state
    ensures process.all_rcvd_duties == process'.all_rcvd_duties
    {}

    lemma lemma_inv4_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state
    ensures process.all_rcvd_duties == process'.all_rcvd_duties
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );                    

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );
            lemma_inv4_f_check_for_next_queued_duty(process, process');
        }
        else
        {}
    }   

    lemma lemma_inv4_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)
    requires s.all_rcvd_duties == s'.all_rcvd_duties
    { } 

    lemma lemma_inv5_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)
    requires inv5_body(s)
    ensures inv5_body(s')
    { } 
    
    lemma lemma_inv5_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state
    requires inv5_body(process)
    ensures inv5_body(process')
    { }  

    lemma lemma_inv5_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state
    requires inv5_body(process)
    ensures inv5_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    lemma_inv5_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );         
                    lemma_inv5_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv5_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv5_body(process)
    ensures inv5_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        

        assert inv5_body(process_mod);

        lemma_inv5_f_check_for_next_queued_duty(process_mod, process');        
    }    

    lemma lemma_inv5_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state 
    requires inv5_body(process)
    ensures inv5_body(process')
    {
        
        if  && process.current_attestation_duty.isPresent()
            && id == process.current_attestation_duty.safe_get().slot
        {
            var local_current_attestation_duty := process.current_attestation_duty.safe_get();
            var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

            var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
            var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
            var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
            var attestation_with_signature_share := AttestationShare(
                    aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                    data := decided_attestation_data, 
                    signature := attestation_signature_share
                ); 

            var process := 
                process.(
                    current_attestation_duty := None,
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                    attestation_slashing_db := attestation_slashing_db,
                    attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                        process.attestation_consensus_engine_state,
                        attestation_slashing_db
                    )
                );

            assert inv5_body(process);

            var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process);
            
            lemma_inv5_f_check_for_next_queued_duty(process, ret_check_for_next_queued_duty.state);

            assert process' == ret_check_for_next_queued_duty.state;
        }
    }  

    lemma lemma_inv5_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state
    requires inv5_body(process)
    ensures inv5_body(process')
    {}

    lemma lemma_inv5_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state
    requires inv5_body(process)
    ensures inv5_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    

        assert inv5_body(process);
                    

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );

            assert inv5_body(process);

            lemma_inv5_f_check_for_next_queued_duty(process, process');
        }
        else
        {
            assert inv5_body(process);
        }
    }  

    lemma lemma_inv6_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state    
    requires attestation_duty in process.all_rcvd_duties
    requires inv6_body(process)
    ensures inv6_body(process')
    { }  

    lemma lemma_inv6_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state
    requires inv5_body(process)
    requires inv6_body(process)
    ensures inv6_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    lemma_inv6_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     
                    assert process.attestation_duties_queue[0] in process.all_rcvd_duties;
                    lemma_inv6_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv6_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv5_body(process)
    requires inv6_body(process)
    ensures inv6_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        

        assert inv6_body(process_mod);

        lemma_inv6_f_check_for_next_queued_duty(process_mod, process');        
    } 

    lemma lemma_inv6_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state 
    requires inv5_body(process)
    requires inv6_body(process)
    ensures inv6_body(process')
    {
        
        if  && process.current_attestation_duty.isPresent()
            && id == process.current_attestation_duty.safe_get().slot
        {
            var local_current_attestation_duty := process.current_attestation_duty.safe_get();
            var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

            var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
            var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
            var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
            var attestation_with_signature_share := AttestationShare(
                    aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                    data := decided_attestation_data, 
                    signature := attestation_signature_share
                ); 

            var process := 
                process.(
                    current_attestation_duty := None,
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                    attestation_slashing_db := attestation_slashing_db,
                    attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                        process.attestation_consensus_engine_state,
                        attestation_slashing_db
                    )
                );

            assert inv6_body(process);

            var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process);
            
            lemma_inv6_f_check_for_next_queued_duty(process, ret_check_for_next_queued_duty.state);

            assert process' == ret_check_for_next_queued_duty.state;
        }        
    }  

    lemma lemma_inv6_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state
    requires inv6_body(process)
    ensures inv6_body(process')
    {}

    lemma lemma_inv6_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state
    requires inv5_body(process)
    requires inv6_body(process)
    ensures inv6_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    

        assert inv6_body(process);
                    

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );

            assert inv5_body(process);
            assert inv6_body(process);

            lemma_inv6_f_check_for_next_queued_duty(process, process');
        }
        else
        {   
            assert inv6_body(process);
        }
    }  

    lemma lemma_inv7_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state    
    requires attestation_duty in process.all_rcvd_duties
    requires inv7_body(process)
    ensures inv7_body(process')
    { }  

    lemma lemma_inv7_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state
    requires inv5_body(process)
    requires inv7_body(process)
    ensures inv7_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    lemma_inv7_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     
                    assert process.attestation_duties_queue[0] in process.all_rcvd_duties;
                    lemma_inv7_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv7_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv5_body(process)
    requires inv7_body(process)
    ensures inv7_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        

        assert inv7_body(process_mod);

        lemma_inv7_f_check_for_next_queued_duty(process_mod, process');        
    } 

    lemma lemma_inv7_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state 
    requires inv5_body(process)
    requires inv7_body(process)
    ensures inv7_body(process')
    {
        
        if  && process.current_attestation_duty.isPresent()
            && id == process.current_attestation_duty.safe_get().slot
        {
            var local_current_attestation_duty := process.current_attestation_duty.safe_get();
            var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

            var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
            var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
            var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
            var attestation_with_signature_share := AttestationShare(
                    aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                    data := decided_attestation_data, 
                    signature := attestation_signature_share
                ); 

            var process := 
                process.(
                    current_attestation_duty := None,
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                    attestation_slashing_db := attestation_slashing_db,
                    attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                        process.attestation_consensus_engine_state,
                        attestation_slashing_db
                    )
                );

            assert inv7_body(process);

            var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process);
            
            lemma_inv7_f_check_for_next_queued_duty(process, ret_check_for_next_queued_duty.state);

            assert process' == ret_check_for_next_queued_duty.state;
        }
        
    }  

    lemma lemma_inv7_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state
    requires inv7_body(process)
    ensures inv7_body(process')
    {}

    lemma lemma_inv7_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state
    requires inv5_body(process)
    requires inv7_body(process)
    ensures inv7_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    

        assert inv7_body(process);
                    

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );

            assert inv5_body(process);
            assert inv7_body(process);

            lemma_inv7_f_check_for_next_queued_duty(process, process');
        }
        else
        {   
            assert inv7_body(process);
        }
    }

    lemma lemma_inv8_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state        
    requires inv8_body(process)
    ensures inv8_body(process')
    { }  

    lemma lemma_inv8_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state    
    requires inv8_body(process)
    ensures inv8_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    lemma_inv8_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     
                    assert inv8_body(process_mod);

                    lemma_inv8_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv8_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv8_body(process)
    ensures inv8_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        
        

        lemma_inv8_f_check_for_next_queued_duty(process_mod, process');        
    } 

    lemma lemma_inv8_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state     
    requires inv8_body(process)
    ensures inv8_body(process')
    {
        
        if  && process.current_attestation_duty.isPresent()
            && id == process.current_attestation_duty.safe_get().slot
        {
            var local_current_attestation_duty := process.current_attestation_duty.safe_get();        
            var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

            var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
            var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
            var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
            var attestation_with_signature_share := AttestationShare(
                    aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                    data := decided_attestation_data, 
                    signature := attestation_signature_share
                ); 

            var process := 
                process.(
                    current_attestation_duty := None,
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                    attestation_slashing_db := attestation_slashing_db,
                    attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                        process.attestation_consensus_engine_state,
                        attestation_slashing_db
                    )
                );

            assert inv8_body(process);

            var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process);
            
            lemma_inv8_f_check_for_next_queued_duty(process, ret_check_for_next_queued_duty.state);

            assert process' == ret_check_for_next_queued_duty.state;
        }
    }  

    lemma lemma_inv8_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state
    requires inv8_body(process)
    ensures inv8_body(process')
    {}

    lemma lemma_inv8_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state    
    requires inv8_body(process)
    ensures inv8_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    

        assert inv8_body(process);
                    

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );
            
            assert inv8_body(process);

            lemma_inv8_f_check_for_next_queued_duty(process, process');
        }
        else
        {   
            assert inv8_body(process);
        }
    }  

    lemma lemma_inv8_f_resend_attestation_share(
        process: DVCState,
        process': DVCState)
    requires f_resend_attestation_share.requires(process)
    requires process' == f_resend_attestation_share(process).state    
    requires inv8_body(process)
    ensures inv8_body(process')
    { }       
         
    lemma lemma_inv8_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)
    requires inv8_body(s)
    ensures inv8_body(s')
    { }    

    lemma lemma_inv9_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state        
    requires inv9_body(process)
    ensures inv9_body(process')
    { }  

    lemma lemma_inv9_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state    
    requires inv9_body(process)
    ensures inv9_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    lemma_inv9_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     
                    assert inv9_body(process_mod);

                    lemma_inv9_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv9_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv8_body(process)  
    requires inv9_body(process)
    ensures inv9_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        
        
        lemma_inv9_f_check_for_next_queued_duty(process_mod, process');        
    } 

    lemma lemma_inv9_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state     
    requires inv9_body(process)
    ensures inv9_body(process')
    {
        
        if  && process.current_attestation_duty.isPresent()
            && id == process.current_attestation_duty.safe_get().slot
        {
            var local_current_attestation_duty := process.current_attestation_duty.safe_get();
            var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

            var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
            var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
            var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
            var attestation_with_signature_share := AttestationShare(
                    aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                    data := decided_attestation_data, 
                    signature := attestation_signature_share
                ); 

            var process := 
                process.(
                    current_attestation_duty := None,
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                    attestation_slashing_db := attestation_slashing_db,
                    attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                        process.attestation_consensus_engine_state,
                        attestation_slashing_db
                    )
                );

            assert inv9_body(process);

            var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process);
            
            lemma_inv9_f_check_for_next_queued_duty(process, ret_check_for_next_queued_duty.state);

            assert process' == ret_check_for_next_queued_duty.state;
        }
    }  

    lemma lemma_inv9_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state
    requires inv9_body(process)
    ensures inv9_body(process')
    {}

    lemma lemma_inv9_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state    
    requires inv9_body(process)
    ensures inv9_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    

        assert inv9_body(process);
                    

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );
            
            assert inv9_body(process);

            lemma_inv9_f_check_for_next_queued_duty(process, process');
        }
        else
        {   
            assert inv9_body(process);
        }
    }  

    lemma lemma_inv9_f_resend_attestation_share(
        process: DVCState,
        process': DVCState)
    requires f_resend_attestation_share.requires(process)
    requires process' == f_resend_attestation_share(process).state    
    requires inv9_body(process)
    ensures inv9_body(process')
    { }       
         
    lemma lemma_inv9_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)
    requires inv9_body(s)
    ensures inv9_body(s')
    { }

    lemma lemma_inv10_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state        
    requires inv10_body(process)
    ensures inv10_body(process')
    { }  

    lemma lemma_inv10_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state    
    requires inv10_body(process)
    ensures inv10_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    lemma_inv10_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     
                    assert inv10_body(process_mod);

                    lemma_inv10_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv10_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv8_body(process)  
    requires inv10_body(process)
    ensures inv10_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        
        
        lemma_inv10_f_check_for_next_queued_duty(process_mod, process');        
    } 

    lemma lemma_inv10_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state     
    requires inv10_body(process)
    ensures inv10_body(process')
    {
        
        if  || !process.current_attestation_duty.isPresent()
            || id != process.current_attestation_duty.safe_get().slot 
        {
            return;
        }

        var local_current_attestation_duty := process.current_attestation_duty.safe_get();

        var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

        var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
        var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
        var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
        var attestation_with_signature_share := AttestationShare(
                aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                data := decided_attestation_data, 
                signature := attestation_signature_share
            ); 

        var process := 
            process.(
                current_attestation_duty := None,
                attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                attestation_slashing_db := attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    attestation_slashing_db
                )
            );

        assert inv10_body(process);

        var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process);
        
        lemma_inv10_f_check_for_next_queued_duty(process, ret_check_for_next_queued_duty.state);

        assert process' == ret_check_for_next_queued_duty.state;
        
    }  

    lemma lemma_inv10_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state
    requires inv10_body(process)
    ensures inv10_body(process')
    {}

    lemma lemma_inv10_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state    
    requires inv10_body(process)
    ensures inv10_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    

        assert inv10_body(process);
                    

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );
            
            assert inv10_body(process);

            lemma_inv10_f_check_for_next_queued_duty(process, process');
        }
        else
        {   
            assert inv10_body(process);
        }
    }  

    lemma lemma_inv10_f_resend_attestation_share(
        process: DVCState,
        process': DVCState)
    requires f_resend_attestation_share.requires(process)
    requires process' == f_resend_attestation_share(process).state    
    requires inv10_body(process)
    ensures inv10_body(process')
    { }       
         
    lemma lemma_inv10_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)
    requires inv10_body(s)
    ensures inv10_body(s')
    { }

    lemma lemma_inv16_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state        
    requires inv8_body(process) || inv16_body(process)
    ensures inv16_body(process')
    { }  

    lemma lemma_inv16_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state    
    requires inv8_body(process) || inv16_body(process)
    ensures inv16_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    lemma_inv16_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     
                    assert inv8_body(process_mod) || inv16_body(process_mod);

                    lemma_inv16_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv16_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv8_body(process)  
    requires inv16_body(process)
    ensures inv16_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        
        
        lemma_inv16_f_check_for_next_queued_duty(process_mod, process');        
    } 

    lemma lemma_inv16_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state     
    requires inv16_body(process)
    ensures inv16_body(process')
    {
        
        if  || !process.current_attestation_duty.isPresent()
            || id != process.current_attestation_duty.safe_get().slot 
        {
            return;
        }

        var local_current_attestation_duty := process.current_attestation_duty.safe_get();

        var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

        var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
        var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
        var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
        var attestation_with_signature_share := AttestationShare(
                aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                data := decided_attestation_data, 
                signature := attestation_signature_share
            ); 

        var process := 
            process.(
                current_attestation_duty := None,
                attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                attestation_slashing_db := attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    attestation_slashing_db
                )
            );

        assert inv16_body(process);

        var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process);
        
        lemma_inv16_f_check_for_next_queued_duty(process, ret_check_for_next_queued_duty.state);

        assert process' == ret_check_for_next_queued_duty.state;
        
    }  

    lemma lemma_inv16_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state
    requires inv16_body(process)
    ensures inv16_body(process')
    {}

    lemma lemma_inv16_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state    
    requires inv16_body(process)
    ensures inv16_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    

        assert inv16_body(process);
                    

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );
            
            assert inv16_body(process);

            lemma_inv16_f_check_for_next_queued_duty(process, process');
        }
        else
        {   
            assert inv16_body(process);
        }
    }  

    lemma lemma_inv16_f_resend_attestation_share(
        process: DVCState,
        process': DVCState)
    requires f_resend_attestation_share.requires(process)
    requires process' == f_resend_attestation_share(process).state    
    requires inv16_body(process)
    ensures inv16_body(process')
    { }       
         
    lemma lemma_inv16_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)
    requires inv16_body(s)
    ensures inv16_body(s')
    { }

    lemma lemma_inv_strictly_increasing_queue_of_att_duties_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state        
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    ensures inv_strictly_increasing_queue_of_att_duties_body(process')
    { }  

    lemma lemma_inv_strictly_increasing_queue_of_att_duties_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state    
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    ensures inv_strictly_increasing_queue_of_att_duties_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    lemma_inv_strictly_increasing_queue_of_att_duties_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     
                    assert inv8_body(process_mod) || inv_strictly_increasing_queue_of_att_duties_body(process_mod);

                    lemma_inv_strictly_increasing_queue_of_att_duties_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv_strictly_increasing_queue_of_att_duties_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    ensures inv_strictly_increasing_queue_of_att_duties_body(process')
    {}

    lemma lemma_inv_strictly_increasing_queue_of_att_duties_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state    
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    ensures inv_strictly_increasing_queue_of_att_duties_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    

        assert inv_strictly_increasing_queue_of_att_duties_body(process);
                    

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );
            
            assert inv_strictly_increasing_queue_of_att_duties_body(process);

            lemma_inv_strictly_increasing_queue_of_att_duties_f_check_for_next_queued_duty(process, process');
        }
        else
        {   
            assert inv_strictly_increasing_queue_of_att_duties_body(process);
        }
    }  

    lemma lemma_inv_strictly_increasing_queue_of_att_duties_f_resend_attestation_share(
        process: DVCState,
        process': DVCState)
    requires f_resend_attestation_share.requires(process)
    requires process' == f_resend_attestation_share(process).state    
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    ensures inv_strictly_increasing_queue_of_att_duties_body(process')
    { }       
         
    lemma lemma_inv_strictly_increasing_queue_of_att_duties_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)
    requires inv_strictly_increasing_queue_of_att_duties_body(s)
    ensures inv_strictly_increasing_queue_of_att_duties_body(s')
    { }

    lemma lemma_inv_strictly_increasing_queue_of_att_duties_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state     
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    ensures inv_strictly_increasing_queue_of_att_duties_body(process')
    {
        
        if  || !process.current_attestation_duty.isPresent()
            || id != process.current_attestation_duty.safe_get().slot 
        {
            return;
        }

        var local_current_attestation_duty := process.current_attestation_duty.safe_get();

        var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

        var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
        var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
        var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
        var attestation_with_signature_share := AttestationShare(
                aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                data := decided_attestation_data, 
                signature := attestation_signature_share
            ); 

        var process := 
            process.(
                current_attestation_duty := None,
                attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                attestation_slashing_db := attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    attestation_slashing_db
                )
            );

        assert inv_strictly_increasing_queue_of_att_duties_body(process);

        var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process);
        
        lemma_inv_strictly_increasing_queue_of_att_duties_f_check_for_next_queued_duty(process, ret_check_for_next_queued_duty.state);

        assert process' == ret_check_for_next_queued_duty.state;
        
    }  

    lemma lemma_inv_strictly_increasing_queue_of_att_duties_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv5_body(process)  
    requires inv15_body(process, attestation_duty)  
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    ensures inv_strictly_increasing_queue_of_att_duties_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        
        
        lemma_inv_strictly_increasing_queue_of_att_duties_f_check_for_next_queued_duty(process_mod, process');        
    } 

    lemma lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state    
    requires inv5_body(process)
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process)
    ensures inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process')
    {}

    lemma lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_resend_attestation_share(
        process: DVCState,
        process': DVCState)
    requires f_resend_attestation_share.requires(process)
    requires process' == f_resend_attestation_share(process).state    
    requires inv5_body(process)
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process)
    ensures inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process')
    { }  
    
    lemma lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)
    requires inv5_body(s)
    requires inv_strictly_increasing_queue_of_att_duties_body(s)
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(s)
    ensures inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(s')
    { }

    lemma lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state   
    requires forall queued_duty: AttestationDuty | queued_duty in process.attestation_duties_queue ::
                        attestation_duty.slot < queued_duty.slot     
    requires inv5_body(process)
    requires inv_strictly_increasing_queue_of_att_duties_body(process)                        
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process)
    ensures inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process')
    { } 

    lemma lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state    
    requires inv5_body(process)
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process)
    ensures inv_strictly_increasing_queue_of_att_duties_body(process')
    ensures inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var next_duty := process.attestation_duties_queue[0];
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     

                    assert forall queued_duty: AttestationDuty | 
                                queued_duty in process_mod.attestation_duties_queue ::
                                    next_duty.slot <= queued_duty.slot;


                    assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process_mod);

                    lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_start_next_duty(process_mod, next_duty, process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv5_body(process)  
    requires inv12_body(process, attestation_duty)  
    requires inv15_body(process, attestation_duty)  
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process)
    requires forall queued_duty: AttestationDuty | queued_duty in process.attestation_duties_queue ::
                        queued_duty.slot < attestation_duty.slot
    ensures inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );  

        if process.latest_attestation_duty.isPresent() 
        {
            assert process_mod.latest_attestation_duty.isPresent();
            assert process.latest_attestation_duty.safe_get()
                        == process_mod.latest_attestation_duty.safe_get();
            assert process.latest_attestation_duty.safe_get().slot < attestation_duty.slot;
            assert process_mod.latest_attestation_duty.safe_get().slot < attestation_duty.slot;
            assert inv_strictly_increasing_queue_of_att_duties_body(process_mod);      
            assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process_mod);      
        }
        else 
        {
            assert !process_mod.latest_attestation_duty.isPresent();
            assert inv_strictly_increasing_queue_of_att_duties_body(process_mod);      
            assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process_mod);      
        }
        
        lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_check_for_next_queued_duty(process_mod, process');        
    } 

    lemma lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state    
    requires inv5_body(process)
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process)
    ensures inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    

        assert inv5_body(process);
        assert inv_strictly_increasing_queue_of_att_duties_body(process);
        assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process);
                    

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );

            assert inv5_body(process);
            assert inv_strictly_increasing_queue_of_att_duties_body(process);
            assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process);

            lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_check_for_next_queued_duty(process, process');
        }
        else
        {               
            assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process);
        }
    } 

    lemma lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state     
    requires inv5_body(process)
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process)
    ensures inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process')
    {
        
        if  || !process.current_attestation_duty.isPresent()
            || id != process.current_attestation_duty.safe_get().slot 
        {
            return;
        }

        var local_current_attestation_duty := process.current_attestation_duty.safe_get();

        var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

        var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
        var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
        var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
        var attestation_with_signature_share := AttestationShare(
                aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                data := decided_attestation_data, 
                signature := attestation_signature_share
            ); 

        var process := 
            process.(
                current_attestation_duty := None,
                attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                attestation_slashing_db := attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    attestation_slashing_db
                )
            );

        assert inv5_body(process);
        assert inv_strictly_increasing_queue_of_att_duties_body(process);
        assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process);

        var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process);
        
        lemma_inv_queued_att_duty_is_higher_than_latest_served_att_duty_f_check_for_next_queued_duty(process, ret_check_for_next_queued_duty.state);

        assert process' == ret_check_for_next_queued_duty.state;        
    }  

    lemma lemma_inv_no_active_consensus_instance_before_receiving_att_duty_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)    
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(s)
    ensures inv_no_active_consensus_instance_before_receiving_att_duty_body(s')
    { }

    lemma lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state        
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(process)
    ensures inv_no_active_consensus_instance_before_receiving_att_duty_body(process')
    {}

    lemma lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state   
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(process)
    ensures inv_no_active_consensus_instance_before_receiving_att_duty_body(process')
    { } 

    lemma lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_resend_attestation_share(
        process: DVCState,
        process': DVCState)
    requires f_resend_attestation_share.requires(process)
    requires process' == f_resend_attestation_share(process).state        
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(process)
    ensures inv_no_active_consensus_instance_before_receiving_att_duty_body(process')
    { } 

    lemma lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state    
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(process)
    ensures inv_no_active_consensus_instance_before_receiving_att_duty_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     
                    assert inv_no_active_consensus_instance_before_receiving_att_duty_body(process_mod);

                    lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state         
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(process)
    ensures inv_no_active_consensus_instance_before_receiving_att_duty_body(process')
    {
        
        if  || !process.current_attestation_duty.isPresent()
            || id != process.current_attestation_duty.safe_get().slot 
        {
            return;
        }

        var local_current_attestation_duty := process.current_attestation_duty.safe_get();

        var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

        var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
        var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
        var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
        var attestation_with_signature_share := AttestationShare(
                aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                data := decided_attestation_data, 
                signature := attestation_signature_share
            ); 

        var process := 
            process.(
                current_attestation_duty := None,
                attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                attestation_slashing_db := attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    attestation_slashing_db
                )
            );

    
        assert inv_no_active_consensus_instance_before_receiving_att_duty_body(process);

        var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process);
        
        lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_check_for_next_queued_duty(process, ret_check_for_next_queued_duty.state);

        assert process' == ret_check_for_next_queued_duty.state;        
    } 
    
    lemma lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state        
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(process)
    ensures inv_no_active_consensus_instance_before_receiving_att_duty_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    
        
        assert inv_no_active_consensus_instance_before_receiving_att_duty_body(process);

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );
            
            assert inv_no_active_consensus_instance_before_receiving_att_duty_body(process);

            lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_check_for_next_queued_duty(process, process');
        }
        else
        {               
            assert inv_no_active_consensus_instance_before_receiving_att_duty_body(process);
        }
    } 

    lemma lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(process)
    ensures inv_no_active_consensus_instance_before_receiving_att_duty_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        
        
        lemma_inv_no_active_consensus_instance_before_receiving_att_duty_f_check_for_next_queued_duty(process_mod, process');        
    } 

    lemma lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)    
    requires inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(s)
    ensures inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(s')
    { }

    lemma lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state        
    requires inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process)
    ensures inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process')
    {}

    lemma lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_f_resend_attestation_share(
        process: DVCState,
        process': DVCState)
    requires f_resend_attestation_share.requires(process)
    requires process' == f_resend_attestation_share(process).state        
    requires inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process)
    ensures inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process')
    { } 

    lemma lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state        
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process)
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(process)
    requires inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process)
    ensures inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );

                    assert inv_strictly_increasing_queue_of_att_duties_body(process_mod);
                    assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process_mod);
                    assert inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process_mod);
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     

                    if process_mod.latest_attestation_duty.isPresent()
                    {
                        assert inv_strictly_increasing_queue_of_att_duties_body(process_mod);
                        assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process_mod);
                        assert inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process_mod);

                        assert  process_mod.latest_attestation_duty.isPresent()
                                    ==> process_mod.latest_attestation_duty.safe_get().slot < process.attestation_duties_queue[0].slot;

                        assert process_mod.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys 
                                    == process.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys;

                        forall k: Slot | k in process_mod.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys 
                        ensures k < process.attestation_duties_queue[0].slot;
                        {
                            assert k in process.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys;
                            assert inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process);
                            assert k <= process.latest_attestation_duty.safe_get().slot;
                            assert process.latest_attestation_duty.safe_get().slot < process.attestation_duties_queue[0].slot;
                            assert k < process.attestation_duties_queue[0].slot;
                        }
                        lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                    }
                    else 
                    {
                        assert inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process');
                    }
                }
        }
        else
        { }
    }

    lemma lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state   
    requires inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process)
    requires ( forall k: Slot | k in process.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys ::
                    k < attestation_duty.slot
            )
    ensures inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process')
    { 
        var new_vp := (ad: AttestationData) 
                                        => consensus_is_valid_attestation_data(
                                                process.attestation_slashing_db, 
                                                ad, 
                                                attestation_duty);                

        var slot := attestation_duty.slot;

        assert process' == process.(
                                    current_attestation_duty := Some(attestation_duty),
                                    latest_attestation_duty := Some(attestation_duty),
                                    attestation_consensus_engine_state := startConsensusInstance(
                                    process.attestation_consensus_engine_state,
                                    attestation_duty.slot,
                                    attestation_duty,
                                    process.attestation_slashing_db
                                    )
                            );

        assert process'.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys 
                    == process.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys 
                            + {attestation_duty.slot};
    } 

    lemma lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv5_body(process)
    requires inv7_body(process)
    requires inv14_body(process, attestation_duty)
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process)
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(process)    
    requires inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process)
    ensures inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        

        assert inv5_body(process_mod);
        assert inv7_body(process_mod);
        assert inv_strictly_increasing_queue_of_att_duties_body(process_mod);                        
        assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process_mod);         
        assert inv_no_active_consensus_instance_before_receiving_att_duty_body(process_mod);         
        assert inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process_mod);
        
        lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_f_check_for_next_queued_duty(process_mod, process');        
    } 

    lemma lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state        
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process)
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(process)
    requires inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process)
    ensures inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process_mod :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    
        
        assert inv_strictly_increasing_queue_of_att_duties_body(process_mod);
        assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process_mod);
        assert inv_no_active_consensus_instance_before_receiving_att_duty_body(process_mod);
        assert inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process_mod);

        if process_mod.current_attestation_duty.isPresent() && process_mod.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process_mod.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process_mod.attestation_slashing_db, decided_attestation_data);
            var temp_process := process_mod.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process_mod.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );
            
            assert inv_strictly_increasing_queue_of_att_duties_body(temp_process);
            assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(temp_process);
            assert inv_no_active_consensus_instance_before_receiving_att_duty_body(temp_process);
            assert inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(temp_process);

            lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_f_check_for_next_queued_duty(temp_process, process');

            assert inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process');
        }
        else
        {               
            assert inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process_mod);
        }
    } 

    lemma lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state         
    requires inv_strictly_increasing_queue_of_att_duties_body(process)
    requires inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process)
    requires inv_no_active_consensus_instance_before_receiving_att_duty_body(process)
    requires inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process)
    ensures inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process')
    {
        
        if  || !process.current_attestation_duty.isPresent()
            || id != process.current_attestation_duty.safe_get().slot 
        {
            return;
        }

        var local_current_attestation_duty := process.current_attestation_duty.safe_get();

        var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

        var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
        var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
        var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
        var attestation_with_signature_share := AttestationShare(
                aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                data := decided_attestation_data, 
                signature := attestation_signature_share
            ); 

        var process_mod := 
            process.(
                current_attestation_duty := None,
                attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                attestation_slashing_db := attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    attestation_slashing_db
                )
            );

        assert inv_strictly_increasing_queue_of_att_duties_body(process_mod);
        assert inv_queued_att_duty_is_higher_than_latest_served_att_duty_body(process_mod);
        assert inv_no_active_consensus_instance_before_receiving_att_duty_body(process_mod);
        assert inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process_mod);

        var ret_check_for_next_queued_duty := f_check_for_next_queued_duty(process_mod);
        
        lemma_inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_f_check_for_next_queued_duty(process_mod, ret_check_for_next_queued_duty.state);

        var res := ret_check_for_next_queued_duty.(
                        state := ret_check_for_next_queued_duty.state,
                        outputs := getEmptyOuputs().(
                                        att_shares_sent := multicast(attestation_with_signature_share, process.peers)
                                    )          
                    );

        assert process' == res.state;
        assert inv_slot_of_active_consensus_instance_is_lower_than_slot_of_latest_served_att_duty_body(process');
    } 

    lemma lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)    
    requires inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(s)
    ensures inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(s')
    { }

    lemma lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state        
    requires inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process)
    ensures inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process')
    { }

    lemma lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state   
    requires attestation_duty in process.all_rcvd_duties
    requires inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process)
    ensures inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process')
    { } 

    lemma lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_resend_attestation_share(
        process: DVCState,
        process': DVCState)
    requires f_resend_attestation_share.requires(process)
    requires process' == f_resend_attestation_share(process).state        
    requires inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process)
    ensures inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process')
    { } 

    lemma lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state    
    requires inv5_body(process)
    requires inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process)
    ensures inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    assert inv5_body(process_mod);
                    lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     
                    assert inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process_mod);

                    lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state         
    requires inv5_body(process)
    requires inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process)
    ensures inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process')
    {
        
        if  || !process.current_attestation_duty.isPresent()
            || id != process.current_attestation_duty.safe_get().slot 
        {
            return;
        }

        var local_current_attestation_duty := process.current_attestation_duty.safe_get();
        
        var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

        var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
        var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
        var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
        var attestation_with_signature_share := AttestationShare(
                aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                data := decided_attestation_data, 
                signature := attestation_signature_share
            ); 

        var process := 
            process.(
                current_attestation_duty := None,
                attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                attestation_slashing_db := attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    attestation_slashing_db
                )
            );

        assert inv5_body(process);
        assert inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process);

        var ret_dvc := f_check_for_next_queued_duty(process).state;
        lemma_inv5_f_check_for_next_queued_duty(process, ret_dvc);
        assert inv5_body(ret_dvc);
        
        lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_check_for_next_queued_duty(process, ret_dvc);
        assert inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(ret_dvc);

        assert process' == ret_dvc;        
    }

    lemma lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv5_body(process)
    requires inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process)
    ensures inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        

        assert inv5_body(process_mod);
        assert inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process_mod);
        
        lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_check_for_next_queued_duty(process_mod, process');        
    }

    lemma lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state        
    requires inv5_body(process)
    requires inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process)
    ensures inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    
        
        assert inv5_body(process);
        assert inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process);

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );
            
            assert inv5_body(process);
            assert inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process);

            lemma_inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_f_check_for_next_queued_duty(process, process');
        }
        else
        {               
            assert inv_consensus_instance_only_for_slot_in_which_dvc_has_rcvd_att_duty_body(process);
        }
    } 

    lemma lemma_inv_consensus_instances_only_for_rcvd_duties_add_block_to_bn(
        s: DVCState,
        block: BeaconBlock,
        s': DVCState 
    )
    requires add_block_to_bn.requires(s, block)
    requires s' == add_block_to_bn(s, block)    
    requires inv_consensus_instances_only_for_rcvd_duties_body(s)
    ensures inv_consensus_instances_only_for_rcvd_duties_body(s')
    { }

    lemma lemma_inv_consensus_instances_only_for_rcvd_duties_f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare,
        process': DVCState
    )
    requires f_listen_for_attestation_shares.requires(process, attestation_share)
    requires process' == f_listen_for_attestation_shares(process, attestation_share).state        
    requires inv_consensus_instances_only_for_rcvd_duties_body(process)
    ensures inv_consensus_instances_only_for_rcvd_duties_body(process')
    { }

    lemma lemma_inv_consensus_instances_only_for_rcvd_duties_f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty, process': DVCState)
    requires f_start_next_duty.requires(process, attestation_duty)
    requires process' == f_start_next_duty(process, attestation_duty).state   
    requires attestation_duty in process.all_rcvd_duties
    requires inv_consensus_instances_only_for_rcvd_duties_body(process)
    ensures inv_consensus_instances_only_for_rcvd_duties_body(process')
    { } 

    lemma lemma_inv_consensus_instances_only_for_rcvd_duties_f_resend_attestation_share(
        process: DVCState,
        process': DVCState)
    requires f_resend_attestation_share.requires(process)
    requires process' == f_resend_attestation_share(process).state        
    requires inv_consensus_instances_only_for_rcvd_duties_body(process)
    ensures inv_consensus_instances_only_for_rcvd_duties_body(process')
    { } 

    lemma lemma_inv_consensus_instances_only_for_rcvd_duties_f_check_for_next_queued_duty(
        process: DVCState,
        process': DVCState
    )
    requires f_check_for_next_queued_duty.requires(process)
    requires process' == f_check_for_next_queued_duty(process).state    
    requires inv5_body(process)
    requires inv_consensus_instances_only_for_rcvd_duties_body(process)
    ensures inv_consensus_instances_only_for_rcvd_duties_body(process')
    decreases process.attestation_duties_queue
    {
        if  && process.attestation_duties_queue != [] 
            && (
                || process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided
                || !process.current_attestation_duty.isPresent()
            )    
        {            
                if process.attestation_duties_queue[0].slot in process.future_att_consensus_instances_already_decided.Keys 
                {
                    var queue_head := process.attestation_duties_queue[0];
                    var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, process.future_att_consensus_instances_already_decided[queue_head.slot]);
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..],
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {queue_head.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
                    assert inv5_body(process_mod);
                    lemma_inv_consensus_instances_only_for_rcvd_duties_f_check_for_next_queued_duty(process_mod, process');
                }
                else
                { 
                    var process_mod := process.(
                        attestation_duties_queue := process.attestation_duties_queue[1..]
                    );     
                    assert inv_consensus_instances_only_for_rcvd_duties_body(process_mod);

                    lemma_inv_consensus_instances_only_for_rcvd_duties_f_start_next_duty(process_mod, process.attestation_duties_queue[0], process');
                }
        }
        else
        { 
            assert process'.all_rcvd_duties == process.all_rcvd_duties;
        }
    }

    lemma lemma_inv_consensus_instances_only_for_rcvd_duties_f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData, 
        process': DVCState
    )
    requires f_att_consensus_decided.requires(process, id, decided_attestation_data)
    requires process' == f_att_consensus_decided(process, id, decided_attestation_data).state         
    requires inv5_body(process)
    requires inv_consensus_instances_only_for_rcvd_duties_body(process)
    ensures inv_consensus_instances_only_for_rcvd_duties_body(process')
    {
        
        if  || !process.current_attestation_duty.isPresent()
            || id != process.current_attestation_duty.safe_get().slot 
        {
            return;
        }

        var local_current_attestation_duty := process.current_attestation_duty.safe_get();

        var attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

        var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
        var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
        var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
        var attestation_with_signature_share := AttestationShare(
                aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                data := decided_attestation_data, 
                signature := attestation_signature_share
            ); 

        var process := 
            process.(
                current_attestation_duty := None,
                attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                attestation_slashing_db := attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    attestation_slashing_db
                )
            );

        assert inv5_body(process);
        assert inv_consensus_instances_only_for_rcvd_duties_body(process);

        var ret_dvc := f_check_for_next_queued_duty(process).state;
        lemma_inv5_f_check_for_next_queued_duty(process, ret_dvc);
        assert inv5_body(ret_dvc);
        
        lemma_inv_consensus_instances_only_for_rcvd_duties_f_check_for_next_queued_duty(process, ret_dvc);
        assert inv_consensus_instances_only_for_rcvd_duties_body(ret_dvc);

        assert process' == ret_dvc;        
    }

    lemma lemma_inv_consensus_instances_only_for_rcvd_duties_f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty,
        process': DVCState
    )  
    requires f_serve_attestation_duty.requires(process, attestation_duty)
    requires process' == f_serve_attestation_duty(process, attestation_duty).state
    requires inv5_body(process)
    requires inv_consensus_instances_only_for_rcvd_duties_body(process)
    ensures inv_consensus_instances_only_for_rcvd_duties_body(process')
    {
        var process_mod := process.(
                attestation_duties_queue := process.attestation_duties_queue + [attestation_duty],
                all_rcvd_duties := process.all_rcvd_duties + {attestation_duty}
            );        

        assert inv5_body(process_mod);
        assert inv_consensus_instances_only_for_rcvd_duties_body(process_mod);
        
        lemma_inv_consensus_instances_only_for_rcvd_duties_f_check_for_next_queued_duty(process_mod, process');        
    }

    lemma lemma_inv_consensus_instances_only_for_rcvd_duties_f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock,
        process': DVCState
    )
    requires f_listen_for_new_imported_blocks.requires(process, block)
    requires process' == f_listen_for_new_imported_blocks(process, block).state        
    requires inv5_body(process)
    requires inv_consensus_instances_only_for_rcvd_duties_body(process)
    ensures inv_consensus_instances_only_for_rcvd_duties_body(process')
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        var process :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );    
        
        assert inv5_body(process);
        assert inv_consensus_instances_only_for_rcvd_duties_body(process);

        if process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided
        {
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process := process.(
                current_attestation_duty := None,
                attestation_slashing_db := new_attestation_slashing_db,
                attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                    process.attestation_consensus_engine_state,
                    new_attestation_slashing_db
                )                
            );
            
            assert inv5_body(process);
            assert inv_consensus_instances_only_for_rcvd_duties_body(process);

            lemma_inv_consensus_instances_only_for_rcvd_duties_f_check_for_next_queued_duty(process, process');
        }
        else
        {               
            assert inv_consensus_instances_only_for_rcvd_duties_body(process);
        }
    } 

    
}