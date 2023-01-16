include "../../common/commons.dfy"
include "../../dvc_implementation/attestation_creation.dfy"
include "../../proofs/no_slashable_attestations/common/dvc_spec_axioms.dfy"

module DVC_Spec_NonInstr {
    import opened Types 
    import opened CommonFunctions
    import opened DVC_Externs
    import opened DVC_Spec_Axioms

    datatype ConsensusEngineState = ConsensusEngineState(
        active_attestation_consensus_instances: map<Slot, AttestationConsensusValidityCheckState>
    )

    function getInitialConensusEngineState(): ConsensusEngineState
    {
        ConsensusEngineState(
            active_attestation_consensus_instances := map[]
        )
    }

    // TODO: add the two following invariants
    // s.active_attestation_consensus_instance.isPresent() <==> process.current_attestation_duty.isPresent()
    // s.active_attestation_consensus_instance..safe_get().slot == process.latest_attestation_duty.safe_get().slot
    // forall slot1, slot2 in s.active_attestation_consensus_instances.Keys :: slot1 == slot2
    function startConsensusInstance(
        s: ConsensusEngineState,
        id: Slot,
        attestation_duty: AttestationDuty,
        attestation_slashing_db: set<SlashingDBAttestation>
    ): ConsensusEngineState
    requires id !in s.active_attestation_consensus_instances.Keys
    {
        var acvc := AttestationConsensusValidityCheckState(
                    attestation_duty := attestation_duty,
                    validityPredicate := (ad: AttestationData) => consensus_is_valid_attestation_data(attestation_slashing_db, ad, attestation_duty)
                );
        
        assert (acvc.validityPredicate == (ad: AttestationData) => consensus_is_valid_attestation_data(attestation_slashing_db, ad, acvc.attestation_duty));
        
        var new_active_attestation_consensus_instances := 
                s.active_attestation_consensus_instances[
                    id := acvc
                ];

        s.(
            active_attestation_consensus_instances := new_active_attestation_consensus_instances
        )
    }

    function addToAttSlashingDBHist(
        hist: map<Slot, map<AttestationData -> bool, set<set<SlashingDBAttestation>>>>,
        id: Slot,
        vp: AttestationData -> bool,
        new_attestation_slashing_db: set<SlashingDBAttestation>
    ): (new_hist: map<Slot, map<AttestationData -> bool, set<set<SlashingDBAttestation>>>>)
    {

            var  hist_id := getOrDefault(hist, id, map[]);
            var new_hist_id_vp := getOrDefault(hist_id, vp, {}) + {new_attestation_slashing_db};
            hist[
                id := hist_id[
                    vp := new_hist_id_vp
                ]
            ]
    }  


    function stopConsensusInstances(
        s: ConsensusEngineState,
        ids: set<Slot>
    ): ConsensusEngineState
    {
        s.(
            active_attestation_consensus_instances := s.active_attestation_consensus_instances - ids
        )
    }    


    function updateConsensusInstanceValidityCheckHelper(
        m: map<Slot, AttestationConsensusValidityCheckState>,
        new_attestation_slashing_db: set<SlashingDBAttestation>
    ): (r: map<Slot, AttestationConsensusValidityCheckState>)
    // Questions: It seems r.Keys == m.Keys, not <=
    ensures r.Keys <= m.Keys
    {
            map it | it in m.Items
                ::
                it.0 := it.1.(
                    validityPredicate := (ad: AttestationData) => consensus_is_valid_attestation_data(new_attestation_slashing_db, ad, it.1.attestation_duty)
                )        
    }

  
    function updateAttSlashingDBHist(
        hist: map<Slot, map<AttestationData -> bool, set<set<SlashingDBAttestation>>>>,
        new_active_attestation_consensus_instances : map<Slot, AttestationConsensusValidityCheckState>,
        new_attestation_slashing_db: set<SlashingDBAttestation>
    ): (new_hist: map<Slot, map<AttestationData -> bool, set<set<SlashingDBAttestation>>>>)
    {
            var ret 
                := map k: Slot | k in (new_active_attestation_consensus_instances.Keys + hist.Keys)
                    ::            
                    if k in new_active_attestation_consensus_instances.Keys then 
                        var vp := new_active_attestation_consensus_instances[k].validityPredicate;
                        var hist_k := getOrDefault(hist, k, map[]);
                        var hist_k_vp := getOrDefault(hist_k, vp, {}) + {new_attestation_slashing_db};
                        hist_k[
                            vp := hist_k_vp
                        ]
                    else
                        hist[k];
            ret
    }

    function updateConsensusInstanceValidityCheck(
        s: ConsensusEngineState,
        new_attestation_slashing_db: set<SlashingDBAttestation>
    ): (r: ConsensusEngineState)
    {
        var new_active_attestation_consensus_instances := updateConsensusInstanceValidityCheckHelper(
                    s.active_attestation_consensus_instances,
                    new_attestation_slashing_db
                );
        s.(
            active_attestation_consensus_instances := new_active_attestation_consensus_instances
        )
    }

    function getInitialRS(
        pubkey: BLSPubkey
    ): RSState
    {
        RSState(
            pubkey := pubkey
        )
    }  

    datatype DVCState = DVCState(
        current_attestation_duty: Optional<AttestationDuty>,
        latest_attestation_duty: Optional<AttestationDuty>,
        attestation_slashing_db: set<SlashingDBAttestation>,
        rcvd_attestation_shares: map<Slot,map<(AttestationData, seq<bool>), set<AttestationShare>>>,
        attestation_shares_to_broadcast: map<Slot, AttestationShare>,
        attestation_consensus_engine_state: ConsensusEngineState,
        peers: set<BLSPubkey>,
        construct_signed_attestation_signature: (set<AttestationShare>) -> Optional<BLSSignature>,
        // TODO: Note difference with spec.py
        dv_pubkey: BLSPubkey,
        future_att_consensus_instances_already_decided:  map<Slot, AttestationData>,
        bn: BNState,
        rs: RSState
    )

    datatype Outputs = Outputs(
        att_shares_sent: set<MessaageWithRecipient<AttestationShare>>,
        attestations_submitted: set<Attestation>
    )    

    function getEmptyOuputs(): Outputs
    {
        Outputs(
            {},
            {}
        )
    }  


    function multicast<M>(m: M, receipients: set<BLSPubkey>): set<MessaageWithRecipient<M>>
    {
        addRecepientsToMessage(m, receipients)
    }

    function multicast_multiple<M>(ms: set<M>, receipients: set<BLSPubkey>): set<MessaageWithRecipient<M>>
    {
        var setWithRecipient := set m | m in ms :: addRecepientsToMessage(m, receipients);
        setUnion(setWithRecipient)
    }    

    datatype DVCStateAndOuputs = DVCStateAndOuputs(
        state: DVCState,
        outputs: Outputs
    )

    predicate Init(
        s: DVCState,
        dv_pubkey: BLSPubkey,
        peers: set<BLSPubkey>,
        construct_signed_attestation_signature: (set<AttestationShare>) -> Optional<BLSSignature>,
        initial_attestation_slashing_db: set<SlashingDBAttestation>,
        rs_pubkey: BLSPubkey
    )
    {
        s == DVCState(
            current_attestation_duty := None,
            latest_attestation_duty := None,
            attestation_slashing_db := initial_attestation_slashing_db,
            rcvd_attestation_shares := map[],
            attestation_shares_to_broadcast := map[],
            attestation_consensus_engine_state := getInitialConensusEngineState(),
            peers := peers,
            construct_signed_attestation_signature := construct_signed_attestation_signature,
            dv_pubkey := dv_pubkey,
            future_att_consensus_instances_already_decided := map[],
            bn := s.bn,
            rs := getInitialRS(rs_pubkey)
        )
    }

    predicate Next(
        s: DVCState,
        event: Event,
        s': DVCState,
        outputs: Outputs
    )
    {
        var newNodeStateAndOutputs := DVCStateAndOuputs(
            state := s',
            outputs := outputs
        );

        && f_process_event.requires(s, event)
        && f_process_event(s, event ) == newNodeStateAndOutputs
    }

    // Processes an input event
    function f_process_event(
        s: DVCState,
        event: Event
    ): DVCStateAndOuputs
    requires
            match event 
            case ServeAttstationDuty(attestation_duty) => 
                && f_serve_attestation_duty.requires(s, attestation_duty)
            case AttConsensusDecided(id, decided_attestation_data) => 
                && f_att_consensus_decided.requires(s, id,  decided_attestation_data)
            case ReceivedAttestationShare(attestation_share) => 
                f_listen_for_attestation_shares.requires(s, attestation_share)
            case ImportedNewBlock(block) => 
                f_listen_for_new_imported_blocks.requires(s, block)
            case ResendAttestationShares => 
                f_resend_attestation_share.requires(s) 
            case NoEvent => 
                true
    {
        match event 
            case ServeAttstationDuty(attestation_duty) => 
                f_serve_attestation_duty(s, attestation_duty)
            case AttConsensusDecided(id, decided_attestation_data) => 
                f_att_consensus_decided(s, id,  decided_attestation_data)
            case ReceivedAttestationShare(attestation_share) => 
                f_listen_for_attestation_shares(s, attestation_share)
            case ImportedNewBlock(block) => 
                f_listen_for_new_imported_blocks(s, block)
            case ResendAttestationShares => 
                f_resend_attestation_share(s)
            case NoEvent => 
                DVCStateAndOuputs(state := s, outputs := getEmptyOuputs() )
    }  

    // Wraps a DVC state with outputs to construct a state with type DVCStateAndOutputs
    function f_wrap_DVCState_with_Outputs(
        dvc: DVCState,
        outputs: Outputs
    ): DVCStateAndOuputs
    {
        DVCStateAndOuputs(
                state := dvc,
                outputs := outputs
            )
    }  

    // An attestation duty has been delivered to a process.
    // Importatnt: Attestation duties are always delivered.
    function f_serve_attestation_duty(
        process: DVCState,
        attestation_duty: AttestationDuty
    ): DVCStateAndOuputs
    // {
    //     if  && attestation_duty.slot !in process.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys
    //         &&  ( || !process.latest_attestation_duty.isPresent()
    //               || process.latest_attestation_duty.safe_get().slot < attestation_duty.slot
    //             )
    //     then
    //         var process_after_stopping_active_consensus_instance := f_terminate_current_attestation_duty(process);
    //         f_check_for_next_duty(
    //             process_after_stopping_active_consensus_instance,
    //             attestation_duty
    //         )
    //     else
    //         f_wrap_DVCState_with_Outputs(process, getEmptyOuputs())
        
    // } 
    requires attestation_duty.slot !in process.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys
    requires || !process.latest_attestation_duty.isPresent()
             || process.latest_attestation_duty.safe_get().slot < attestation_duty.slot
    {        
        var process_after_stopping_active_consensus_instance := f_terminate_current_attestation_duty(process);
        f_check_for_next_duty(
            process_after_stopping_active_consensus_instance,
            attestation_duty
        )
    } 

    function f_terminate_current_attestation_duty(
        process: DVCState
    ): (ret_process: DVCState)
    ensures !ret_process.current_attestation_duty.isPresent()
    {
        // There exists an active consensus instance for the current attestation duty.
        // In other words, a process has not know a decision for the current attestation duty.
        if process.current_attestation_duty.isPresent()
        then 
            var process_after_stopping_active_consensus_instance :=
                    process.(
                        current_attestation_duty := None,
                        attestation_consensus_engine_state := stopConsensusInstances(
                                        process.attestation_consensus_engine_state,
                                        {process.current_attestation_duty.safe_get().slot}
                        )               
                    );                    
            process_after_stopping_active_consensus_instance
        // Either a process did not receive any attestation duty before
        // or it knew a decision for the last attestation duty.
        else 
            process
    }      

    function f_check_for_next_duty(
        process: DVCState,
        attestation_duty: AttestationDuty
    ): DVCStateAndOuputs
    requires !process.current_attestation_duty.isPresent()
    requires attestation_duty.slot !in process.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys
    requires || !process.latest_attestation_duty.isPresent()
             || process.latest_attestation_duty.safe_get().slot < attestation_duty.slot
    {
        // attestation_duty is a future duty but a process already knew the decision for this duty.
        // A decision was informed through the delivery of blocks.
        if attestation_duty.slot in process.future_att_consensus_instances_already_decided.Keys then
            // Constructs a new attestation slashing database
            var new_attestation_slashing_db := 
                    f_update_attestation_slashing_db(
                        process.attestation_slashing_db, 
                        process.future_att_consensus_instances_already_decided[attestation_duty.slot]
                    );
            // Removes the decision of attestation_duty.
            // Updates the attestation slashing database and validity checking predicates.
            var new_process := 
                    process.(
                        current_attestation_duty := Some(attestation_duty),
                        latest_attestation_duty := Some(attestation_duty),
                        future_att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided - {attestation_duty.slot},
                        attestation_slashing_db := new_attestation_slashing_db,
                        attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                            process.attestation_consensus_engine_state,
                            new_attestation_slashing_db
                        )                        
                    );
            f_wrap_DVCState_with_Outputs(new_process, getEmptyOuputs())
        else
            f_start_next_duty(process, attestation_duty)
    }         

    // IMPORTANT
    function f_start_next_duty(process: DVCState, attestation_duty: AttestationDuty): DVCStateAndOuputs
    requires attestation_duty.slot !in process.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys
    requires || !process.latest_attestation_duty.isPresent()
             || process.latest_attestation_duty.safe_get().slot < attestation_duty.slot
    {
        var new_process := 
                process.(
                            current_attestation_duty := Some(attestation_duty),
                            latest_attestation_duty := Some(attestation_duty),
                            attestation_consensus_engine_state := startConsensusInstance(
                                process.attestation_consensus_engine_state,
                                attestation_duty.slot,
                                attestation_duty,
                                process.attestation_slashing_db
                            )
                );
        f_wrap_DVCState_with_Outputs(new_process, getEmptyOuputs())
    }      

    function get_aggregation_bits(
        index: nat
    ): seq<bool>
    {
        seq(index, i => if i + 1 == index then true else false)
    } 

    function f_update_attestation_slashing_db(attestation_slashing_db: set<SlashingDBAttestation>, attestation_data: AttestationData): set<SlashingDBAttestation>     
    {
        var slashing_db_attestation := SlashingDBAttestation(
                                            source_epoch := attestation_data.source.epoch,
                                            target_epoch := attestation_data.target.epoch,
                                            signing_root := Some(hash_tree_root(attestation_data)));
        
        attestation_slashing_db + {slashing_db_attestation}
    }      

    function f_calc_att_with_sign_share_from_decided_att_data(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData
    ): AttestationShare
    requires process.current_attestation_duty.isPresent()
    {
        var local_current_attestation_duty := process.current_attestation_duty.safe_get();
        var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(decided_attestation_data.target.epoch));
        var attestation_signing_root := compute_attestation_signing_root(decided_attestation_data, fork_version);
        var attestation_signature_share := rs_sign_attestation(decided_attestation_data, fork_version, attestation_signing_root, process.rs);
        var attestation_with_signature_share := 
                AttestationShare(
                    aggregation_bits := get_aggregation_bits(local_current_attestation_duty.validator_index),
                    data := decided_attestation_data, 
                    signature := attestation_signature_share
                ); 

        attestation_with_signature_share
    }

    function f_update_att_slashing_db_and_consensus_engine_after_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData,
        attestation_with_signature_share: AttestationShare,
        new_attestation_slashing_db: set<SlashingDBAttestation>
    ): DVCState
    requires process.current_attestation_duty.isPresent()
    requires id == process.current_attestation_duty.safe_get().slot
    {
        var local_current_attestation_duty := process.current_attestation_duty.safe_get();
        
        var ret_process := 
                process.(
                    current_attestation_duty := None,
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast[local_current_attestation_duty.slot := attestation_with_signature_share],
                    attestation_slashing_db := new_attestation_slashing_db,
                    attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                        process.attestation_consensus_engine_state,
                        new_attestation_slashing_db
                    )
                );
        
        ret_process
    }

    function f_att_consensus_decided(
        process: DVCState,
        id: Slot,
        decided_attestation_data: AttestationData
    ): DVCStateAndOuputs
    {
        if  && process.current_attestation_duty.isPresent()
            && id == process.current_attestation_duty.safe_get().slot
            && id == decided_attestation_data.slot
        then

            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);

            var attestation_with_signature_share := f_calc_att_with_sign_share_from_decided_att_data(
                                                        process,
                                                        id,
                                                        decided_attestation_data
                                                    );

            var process_mod := 
                    f_update_att_slashing_db_and_consensus_engine_after_att_consensus_decided(
                            process,
                            id,
                            decided_attestation_data,
                            attestation_with_signature_share,
                            new_attestation_slashing_db
                        );         

            var outputs := getEmptyOuputs().(
                                    att_shares_sent := multicast(attestation_with_signature_share, process.peers)
                                );
             
            f_wrap_DVCState_with_Outputs(process_mod, outputs)       
        else   
            f_wrap_DVCState_with_Outputs(process, getEmptyOuputs())            
    }    

    function f_listen_for_attestation_shares(
        process: DVCState,
        attestation_share: AttestationShare
    ): DVCStateAndOuputs
    {
        var activate_att_consensus_intances := process.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys;

        if 
            || (activate_att_consensus_intances == {} && !process.latest_attestation_duty.isPresent())
            || (activate_att_consensus_intances != {} && minInSet(activate_att_consensus_intances) <= attestation_share.data.slot)
            // The following condition may be never satisfied because
            // if process.current_attestation_duty.isPresent() is true 
            // then the attestation consensus instance of process.current_attestation_duty.safe_get() must be active.
            // TODO: add an invariant such that 
            //      process.current_attestation_duty.isPresent() 
            //      ==> 
            //      process.attestation_consensus_engine_state.active_attestation_consensus_instances.Keys != {}
            // || (activate_att_consensus_intances == {} && process.current_attestation_duty.isPresent() && process.current_attestation_duty.safe_get().slot <= attestation_share.data.slot)                
            || (activate_att_consensus_intances == {} && !process.current_attestation_duty.isPresent() && process.latest_attestation_duty.isPresent() && process.latest_attestation_duty.safe_get().slot < attestation_share.data.slot) then

                var k := (attestation_share.data, attestation_share.aggregation_bits);
                var attestation_shares_db_at_slot := getOrDefault(process.rcvd_attestation_shares, attestation_share.data.slot, map[]);
                
                var new_attestation_shares_db := 
                        process.rcvd_attestation_shares[
                            attestation_share.data.slot := 
                                attestation_shares_db_at_slot[
                                            k := 
                                                getOrDefault(attestation_shares_db_at_slot, k, {}) + 
                                                {attestation_share}
                                            ]
                                ];

                var process_with_new_att_shares_db := 
                        process.(
                            rcvd_attestation_shares := new_attestation_shares_db
                        );

                            
                if process_with_new_att_shares_db.construct_signed_attestation_signature(process_with_new_att_shares_db.rcvd_attestation_shares[attestation_share.data.slot][k]).isPresent() then
                    var aggregated_attestation := 
                        f_construct_aggregated_attestation_for_new_attestation_share(
                            attestation_share,
                            k, 
                            process_with_new_att_shares_db.construct_signed_attestation_signature,
                            process_with_new_att_shares_db.rcvd_attestation_shares
                        );

                    var new_outputs := getEmptyOuputs().(
                                                attestations_submitted := {aggregated_attestation} 
                                            );

                    var process_after_submitting_attestations := 
                        process_with_new_att_shares_db.(
                            bn := process_with_new_att_shares_db.bn.(
                                attestations_submitted := process_with_new_att_shares_db.bn.attestations_submitted + [aggregated_attestation]
                            )
                        );

                    f_wrap_DVCState_with_Outputs(process_after_submitting_attestations, new_outputs)  
                else 
                    f_wrap_DVCState_with_Outputs(process, getEmptyOuputs())    
        else 
            f_wrap_DVCState_with_Outputs(process, getEmptyOuputs())          
    }
 
    predicate isMyAttestation(
        a: Attestation,
        bn: BNState,
        block: BeaconBlock,
        valIndex: Optional<ValidatorIndex>
    )
    requires block.body.state_root in bn.state_roots_of_imported_blocks
    {
            && var committee := bn_get_epoch_committees(bn, block.body.state_root, a.data.index);
            && valIndex.Some?
            && valIndex.v in committee
            && var i:nat :| i < |committee| && committee[i] == valIndex.v;
            && i < |a.aggregation_bits|
            && a.aggregation_bits[i]         
    }

    function f_listen_for_new_imported_blocks_helper_1(
        process: DVCState,
        block: BeaconBlock
    ): map<Slot, AttestationData>
    requires block.body.state_root in process.bn.state_roots_of_imported_blocks
    requires    var valIndex := bn_get_validator_index(process.bn, block.body.state_root, process.dv_pubkey);
                forall a1, a2 | 
                        && a1 in block.body.attestations
                        && isMyAttestation(a1, process.bn, block, valIndex)
                        && a2 in block.body.attestations
                        && isMyAttestation(a2, process.bn, block, valIndex)                        
                    ::
                        a1.data.slot == a2.data.slot ==> a1 == a2    
    {
        // Important: The following code allows a process to import decisions of past attestation duties.
        // We proved correctness of this code in version 1.
        // In version 2, we want to simplify the specification by forcing a process not to import
        // decisions of past attestation duties.
        // In other words, only decisions of future attestation duties will be imported in version 2.
        // var valIndex := bn_get_validator_index(process.bn, block.body.state_root, process.dv_pubkey);
        // map a |
        //         && a in block.body.attestations
        //         && isMyAttestation(a, process.bn, block, valIndex)
        //     ::
        //         a.data.slot := a.data 

        var valIndex := bn_get_validator_index(process.bn, block.body.state_root, process.dv_pubkey);
        map a |
                && a in block.body.attestations
                && isMyAttestation(a, process.bn, block, valIndex)
                && ( || !process.latest_attestation_duty.isPresent()
                     || ( && process.latest_attestation_duty.isPresent() 
                          && process.latest_attestation_duty.safe_get().slot < a.data.slot ) )
            ::
                a.data.slot := a.data        
    }

    function f_listen_for_new_imported_blocks_helper_2(
        process: DVCState,
        att_consensus_instances_already_decided: map<Slot, AttestationData>
    ): map<int, AttestationData>
    {
        if process.latest_attestation_duty.isPresent() then
            var old_instances := 
                    set i | 
                        && i in att_consensus_instances_already_decided.Keys
                        && i <= process.latest_attestation_duty.safe_get().slot
                    ;
            att_consensus_instances_already_decided - old_instances
        else
            att_consensus_instances_already_decided     
    }

    function f_listen_for_new_imported_blocks(
        process: DVCState,
        block: BeaconBlock
    ): DVCStateAndOuputs
    requires block.body.state_root in process.bn.state_roots_of_imported_blocks
    requires    var valIndex := bn_get_validator_index(process.bn, block.body.state_root, process.dv_pubkey);
                forall a1, a2 | 
                        && a1 in block.body.attestations
                        && isMyAttestation(a1, process.bn, block, valIndex)
                        && a2 in block.body.attestations
                        && isMyAttestation(a2, process.bn, block, valIndex)                        
                    ::
                        a1.data.slot == a2.data.slot ==> a1 == a2
    {
        var new_consensus_instances_already_decided := f_listen_for_new_imported_blocks_helper_1(process, block);

        var att_consensus_instances_already_decided := process.future_att_consensus_instances_already_decided + new_consensus_instances_already_decided;

        var future_att_consensus_instances_already_decided := 
            f_listen_for_new_imported_blocks_helper_2(process, att_consensus_instances_already_decided);

        // TODO: Do we need to stop consensus instances here?
        var process_after_stopping_consensus_instance :=
                process.(
                    future_att_consensus_instances_already_decided := future_att_consensus_instances_already_decided,
                    attestation_consensus_engine_state := stopConsensusInstances(
                                    process.attestation_consensus_engine_state,
                                    att_consensus_instances_already_decided.Keys
                    ),
                    attestation_shares_to_broadcast := process.attestation_shares_to_broadcast - att_consensus_instances_already_decided.Keys,
                    rcvd_attestation_shares := process.rcvd_attestation_shares - att_consensus_instances_already_decided.Keys                    
                );                    

        // TODO: Do we still need to have the if branch
        if process_after_stopping_consensus_instance.current_attestation_duty.isPresent() && process_after_stopping_consensus_instance.current_attestation_duty.safe_get().slot in att_consensus_instances_already_decided then
            var decided_attestation_data := att_consensus_instances_already_decided[process.current_attestation_duty.safe_get().slot];
            var new_attestation_slashing_db := f_update_attestation_slashing_db(process.attestation_slashing_db, decided_attestation_data);
            var process_after_updating_validity_check := 
                    process_after_stopping_consensus_instance.(
                    current_attestation_duty := None,
                    attestation_slashing_db := new_attestation_slashing_db,
                    attestation_consensus_engine_state := updateConsensusInstanceValidityCheck(
                        process_after_stopping_consensus_instance.attestation_consensus_engine_state,
                        new_attestation_slashing_db
                    )                
            );
            f_wrap_DVCState_with_Outputs(process_after_updating_validity_check, getEmptyOuputs()) 
        else
            f_wrap_DVCState_with_Outputs(process, getEmptyOuputs())    
    }    
  
    function f_resend_attestation_share(
        process: DVCState
    ): DVCStateAndOuputs
    {
        var new_outputs := getEmptyOuputs().(
                                    att_shares_sent :=
                                        multicast_multiple(process.attestation_shares_to_broadcast.Values, process.peers)
                                );
        f_wrap_DVCState_with_Outputs(process, new_outputs)    
    }        

    // Is node n the owner of a given attestation share att
    predicate is_owner_of_att_share(att_share: AttestationShare, dvc: DVCState)
    {
        && var data := att_share.data;
        && var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(data.target.epoch));
        && var att_signing_root := compute_attestation_signing_root(data, fork_version);
        && var att_share_signature := rs_sign_attestation(data, fork_version, att_signing_root, dvc.rs);        
        && att_share_signature == att_share.signature
    }
}

module DVC_Externs_Proofs refines DVC_Externs
{
    import opened DVC_Spec_NonInstr
    import opened DVC_Spec_Axioms

    function toBNState(bn: BeaconNode): BNState
    reads bn
    {
        BNState(
            state_roots_of_imported_blocks := bn.state_roots_of_imported_blocks,
            attestations_submitted := bn.attestations_submitted
        )
    }

    trait BeaconNode...
    {
        method get_fork_version...
        ensures bn_get_fork_version(s) == v

        method get_validator_index...
        ensures state_id in this.state_roots_of_imported_blocks ==> bn_get_validator_index(toBNState(this),state_id, validator_id) == vi

        method get_epoch_committees...
        ensures state_id in this.state_roots_of_imported_blocks ==> bn_get_epoch_committees(toBNState(this), state_id, index) == sv
    }


    trait RemoteSigner...
    {
        method sign_attestation...
        ensures rs_sign_attestation(attestation_data, fork_version, signing_root, toRSState(this)) == s
    }

    function toRSState(
        rs: RemoteSigner
    ): RSState
    reads rs 
    {
        RSState(
            pubkey := rs.pubkey
        )
    }

}