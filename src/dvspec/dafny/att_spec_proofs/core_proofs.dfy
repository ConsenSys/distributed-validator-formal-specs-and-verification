include "../commons.dfy"
include "../specification/dvc_spec.dfy"
include "../specification/consensus.dfy"
include "../specification/network.dfy"
include "../specification/dvn.dfy"
include "../att_spec_proofs/inv.dfy"
include "../att_spec_proofs/ind_inv.dfy"
include "../att_spec_proofs/helper_sets_lemmas.dfy"

module Core_Proofs
{
    import opened Types 
    import opened CommonFunctions
    import opened ConsensusSpec
    import opened NetworkSpec
    import opened DVCNode_Spec
    import opened DV
    import opened Att_Inv_With_Empty_Initial_Attestation_Slashing_DB
    import opened Att_Ind_Inv_With_Empty_Initial_Attestation_Slashing_DB
    import opened Helper_Sets_Lemmas

   

    predicate is_slashable_attestation_data_eth_spec(data_1: AttestationData, data_2: AttestationData)
    {
        || (data_1 != data_2 && data_1.target.epoch == data_2.target.epoch)
        || (data_1.source.epoch < data_2.source.epoch && data_2.target.epoch < data_1.target.epoch)
    }


    lemma lemma_4_1_a(dvn: DVState, a: Attestation, a': Attestation, hn: BLSPubkey, hn': BLSPubkey)
    requires |dvn.all_nodes| > 0
    requires pred_4_1_b(dvn)
    requires pred_4_1_c(dvn)
    requires pred_4_1_f_a(dvn)
    requires inv42(dvn)
    requires pred_4_1_g_i(dvn)
    requires pred_4_1_g_ii(dvn)
    requires hn in dvn.honest_nodes_states.Keys 
    requires hn' in dvn.honest_nodes_states.Keys
    requires a in dvn.honest_nodes_states[hn].bn.attestations_submitted
    requires a' in dvn.honest_nodes_states[hn'].bn.attestations_submitted
    requires a.data.slot < a'.data.slot 
    requires isConditionForSafetyTrue(dvn.consensus_on_attestation_data[a.data.slot])
    requires isConditionForSafetyTrue(dvn.consensus_on_attestation_data[a'.data.slot])
    requires inv48(dvn)
    requires inv47(dvn)
    requires inv46_a(dvn)
    requires inv46_b(dvn)
    // ensures && !is_slashable_attestation_data_eth_spec(a.data, a'.data)
    //         && !is_slashable_attestation_data_eth_spec(a'.data, a.data)
    {
        var hna, att_share :|
                && hna in dvn.honest_nodes_states.Keys 
                && att_share in dvn.att_network.allMessagesSent
                && att_share.data == a.data
                && var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(att_share.data.target.epoch));
                && var attestation_signing_root := compute_attestation_signing_root(att_share.data, fork_version);
                && verify_bls_siganture(attestation_signing_root, att_share.signature, hna);     

        var hna', att_share' :|
                && hna' in dvn.honest_nodes_states.Keys 
                && att_share' in dvn.att_network.allMessagesSent
                && att_share'.data == a'.data
                && var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(att_share'.data.target.epoch));
                && var attestation_signing_root := compute_attestation_signing_root(att_share'.data, fork_version);
                && verify_bls_siganture(attestation_signing_root, att_share'.signature, hna');  

        assert
                && dvn.consensus_on_attestation_data[att_share.data.slot].decided_value.isPresent()
                && dvn.consensus_on_attestation_data[att_share.data.slot].decided_value.safe_get() == att_share.data;       

        assert
                && dvn.consensus_on_attestation_data[att_share'.data.slot].decided_value.isPresent()
                && dvn.consensus_on_attestation_data[att_share'.data.slot].decided_value.safe_get() == att_share'.data;   

        var consa := dvn.consensus_on_attestation_data[a.data.slot];
        var consa' := dvn.consensus_on_attestation_data[a'.data.slot];                    

        assert is_a_valid_decided_value(consa); 
        assert is_a_valid_decided_value(consa');  

        assert consa.decided_value.isPresent();

        var h_nodes_a :| && is_a_valid_decided_value_according_to_set_of_nodes(consa, h_nodes_a)
                         && h_nodes_a == consa.quorum_made_decision;
        var h_nodes_a' :| && is_a_valid_decided_value_according_to_set_of_nodes(consa', h_nodes_a')
                          && h_nodes_a' == consa'.quorum_made_decision;

        assert consa.all_nodes == consa'.all_nodes == dvn.all_nodes;

        var nodes := consa.all_nodes;
        var honest_nodes := consa.honest_nodes_status.Keys;
        var byz_nodes := nodes - honest_nodes;
        
        assert h_nodes_a * byz_nodes == {};
        assert h_nodes_a' * byz_nodes == {};        

        assert |h_nodes_a + byz_nodes| >= quorum(|nodes|);
        assert |h_nodes_a' + byz_nodes| >= quorum(|nodes|);
        assert |byz_nodes| <= f(|nodes|);
        assert nodes != {};    

        lemmaQuorumIntersection(nodes, byz_nodes, h_nodes_a + byz_nodes, h_nodes_a' + byz_nodes);
            
        var m: BLSPubkey :| m in honest_nodes && m in h_nodes_a && m in h_nodes_a';  

        assert m in  consa.honest_nodes_validity_functions.Keys; 
        assert m in  consa'.honest_nodes_validity_functions.Keys; 

        // var vpa: AttestationData -> bool :| 
        //   vpa in consa.honest_nodes_validity_functions[m] && vpa(consa.decided_value.safe_get()); 

        var dva := consa.decided_value.safe_get();
        var dva' := consa'.decided_value.safe_get();

        var sdba := construct_SlashingDBAttestation_from_att_data(dva);

/*
        var vpa': AttestationData -> bool :| 
            vpa' in consa'.honest_nodes_validity_functions[m] && vpa'(dva'); 

        var attestation_duty', attestation_slashing_db' :|
                vpa' == (ad: AttestationData) => consensus_is_valid_attestation_data(attestation_slashing_db', ad, attestation_duty');   
*/
        assert inv48_body(dvn, a'.data.slot, m);      
        assert consa'.honest_nodes_validity_functions[m] != {};

        var vpa': AttestationData -> bool :| vpa' in consa'.honest_nodes_validity_functions[m];
        var s1 := a.data.slot;
        var s2 := a'.data.slot;
        var m_state := dvn.honest_nodes_states[m];
        assert inv46_b_body(dvn, m, s2, vpa');        
        assert vpa' in m_state.att_slashing_db_hist[s2];
        var db2 := m_state.att_slashing_db_hist[s2][vpa'];

        assert s2 in m_state.att_slashing_db_hist.Keys;
        assert s1 < s2;
        assert && m in dvn.consensus_on_attestation_data[s1].honest_nodes_validity_functions.Keys
               && m in dvn.consensus_on_attestation_data[s2].honest_nodes_validity_functions.Keys
               ;            
        assert && vpa' in dvn.consensus_on_attestation_data[s2].honest_nodes_validity_functions[m]        
               && vpa' in m_state.att_slashing_db_hist[s2].Keys
               ;                    
        assert inv47_body(dvn, m, s2);
            
        assert pred_4_1_g_ii_body.requires(dvn, m, s1, s2, vpa', db2);    

        assert sdba in db2;

        /*
        assert !is_slashable_attestation_data(db2, a'.data);

        var sdba' := construct_SlashingDBAttestation_from_att_data(a'.data);

        lemma_is_slashable_attestation_data(db2, a'.data, sdba', sdba);
        assert !is_slashable_attestation_data_eth_spec(a.data, a'.data);
        assert !is_slashable_attestation_data_eth_spec(a'.data, a.data);

        */


        /*
        assert sdba in attestation_slashing_db';     

        assert !is_slashable_attestation_data(attestation_slashing_db', a'.data);

        var sdba' := SlashingDBAttestation(
                                        source_epoch := a'.data.source.epoch,
                                        target_epoch := a'.data.target.epoch,
                                        signing_root := None);        

        lemma_is_slashable_attestation_data(attestation_slashing_db', a'.data, sdba', sdba);
        assert !is_slashable_attestation_data_eth_spec(a.data, a'.data);
        assert !is_slashable_attestation_data_eth_spec(a'.data, a.data);
        */
    }    


/*
    lemma lemma_4_1_b(dvn: DVState, a: Attestation, a': Attestation, hn: BLSPubkey, hn': BLSPubkey)
    requires |dvn.all_nodes| > 0
    requires pred_4_1_b(dvn)
    requires pred_4_1_c(dvn)
    requires pred_4_1_f_a(dvn)
    requires inv42(dvn)
    requires pred_4_1_g_i(dvn)
    requires pred_4_1_g_ii(dvn)
    requires hn in dvn.honest_nodes_states.Keys 
    requires hn' in dvn.honest_nodes_states.Keys
    requires a in dvn.honest_nodes_states[hn].bn.attestations_submitted
    requires a' in dvn.honest_nodes_states[hn'].bn.attestations_submitted
    requires a.data.slot == a'.data.slot 
    requires isConditionForSafetyTrue(dvn.consensus_on_attestation_data[a.data.slot])
    requires isConditionForSafetyTrue(dvn.consensus_on_attestation_data[a'.data.slot])
    ensures && !is_slashable_attestation_data_eth_spec(a.data, a'.data)
            && !is_slashable_attestation_data_eth_spec(a'.data, a.data)
    {
        var hna, att_share :|
                && hna in dvn.honest_nodes_states.Keys 
                && att_share in dvn.att_network.allMessagesSent
                && att_share.data == a.data
                && var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(att_share.data.target.epoch));
                && var attestation_signing_root := compute_attestation_signing_root(att_share.data, fork_version);
                && verify_bls_siganture(attestation_signing_root, att_share.signature, hna);     

        var hna', att_share' :|
                && hna' in dvn.honest_nodes_states.Keys 
                && att_share' in dvn.att_network.allMessagesSent
                && att_share'.data == a'.data
                && var fork_version := bn_get_fork_version(compute_start_slot_at_epoch(att_share'.data.target.epoch));
                && var attestation_signing_root := compute_attestation_signing_root(att_share'.data, fork_version);
                && verify_bls_siganture(attestation_signing_root, att_share'.signature, hna');  

        var cons := dvn.consensus_on_attestation_data[a.data.slot];                 

        assert
                && cons.decided_value.isPresent()
                && cons.decided_value.safe_get() == att_share.data
                && cons.decided_value.safe_get() == att_share'.data;     

        assert a.data == a'.data;  

        assert !is_slashable_attestation_data_eth_spec(a.data, a'.data);
        assert !is_slashable_attestation_data_eth_spec(a'.data, a.data);        
    }      

    lemma lemma_4_1_general(dvn: DVState, a: Attestation, a': Attestation, hn: BLSPubkey, hn': BLSPubkey)
    requires |dvn.all_nodes| > 0
    requires pred_4_1_b(dvn)
    requires pred_4_1_c(dvn)
    requires pred_4_1_f_a(dvn)
    requires inv42(dvn)
    requires pred_4_1_g_i(dvn)
    requires pred_4_1_g_ii(dvn)
    requires hn in dvn.honest_nodes_states.Keys 
    requires hn' in dvn.honest_nodes_states.Keys
    requires a in dvn.honest_nodes_states[hn].bn.attestations_submitted
    requires a' in dvn.honest_nodes_states[hn'].bn.attestations_submitted
    requires isConditionForSafetyTrue(dvn.consensus_on_attestation_data[a.data.slot])
    requires isConditionForSafetyTrue(dvn.consensus_on_attestation_data[a'.data.slot])
    ensures && !is_slashable_attestation_data_eth_spec(a.data, a'.data)
            && !is_slashable_attestation_data_eth_spec(a'.data, a.data)   
    {
        if a.data.slot == a'.data.slot 
        {
            lemma_4_1_b(dvn, a, a', hn, hn');
        }
        else if a.data.slot < a'.data.slot 
        {
            lemma_4_1_a(dvn, a, a', hn, hn');
        }
        else {
            lemma_4_1_a(dvn, a', a, hn', hn);
        }
    } 
*/
    lemma lemma_is_slashable_attestation_data(
        att_slashing_db: set<SlashingDBAttestation>, 
        ad: AttestationData,
        sdba: SlashingDBAttestation,
        sdba': SlashingDBAttestation

    )
    requires !is_slashable_attestation_data(att_slashing_db, ad)
    requires sdba' in att_slashing_db
    requires sdba.source_epoch == ad.source.epoch 
    requires sdba.target_epoch == ad.target.epoch 
    ensures !is_slashable_attestation_pair(sdba, sdba')
    ensures !is_slashable_attestation_pair(sdba', sdba)
    {

    }
            
                    
        // TODO: Prove 4 g - i with lemma_decided_value_is_not_slashable_with_slashing_db_that_constructed_vp
        // and invariants 43--45.

/*
    lemma lemma_decided_value_is_not_slashable_with_slashing_db_that_constructed_vp(
        dvn: DVState, 
        hn: BLSPubkey, 
        s: Slot,
        att: SlashingDBAttestation)
    requires inv43_body_a.requires(dvn, hn, s)    
    requires inv43_body_b.requires(dvn, hn, s)        
    requires att in dvn.honest_nodes_states[hn].att_slashing_db_hist[s]
    requires dvn.consensus_on_attestation_data[s].decided_value.isPresent()
    ensures && var att_data := dvn.consensus_on_attestation_data[s].decided_value.safe_get();
            && var newRecord := construct_SlashingDBAttestation_from_att_data(att_data);
            && forall dbRecord | dbRecord in dvn.honest_nodes_states[hn].attestation_slashing_db ::
                    && !is_slashable_attestation_pair(dbRecord, newRecord)
                    && !is_slashable_attestation_pair(newRecord, dbRecord)
*/
    

}