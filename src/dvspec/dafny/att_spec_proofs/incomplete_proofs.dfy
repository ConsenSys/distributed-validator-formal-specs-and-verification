include "../commons.dfy"
include "../specification/dvc_spec.dfy"
include "../specification/consensus.dfy"
include "../specification/network.dfy"
include "../specification/dvn.dfy"
include "../att_spec_proofs/inv.dfy"
include "../att_spec_proofs/assump.dfy"
include "../att_spec_proofs/fnc_invs_1_26.dfy"
include "../att_spec_proofs/helper_sets_lemmas.dfy"
include "../att_spec_proofs/dvn_next_invs_1_7.dfy"
include "../att_spec_proofs/dvn_next_invs_8_18.dfy"
include "../att_spec_proofs/dvn_next_invs_19_26.dfy"
include "../att_spec_proofs/common_proofs.dfy"
include "../att_spec_proofs/fnc_invs_27.dfy"

module Incomplete_Proofs 
{
    import opened Types 
    import opened CommonFunctions
    import opened ConsensusSpec
    import opened NetworkSpec
    import opened DVCNode_Spec
    import opened DV
    import opened Att_Inv_With_Empty_Initial_Attestation_Slashing_DB    
    import opened Helper_Sets_Lemmas
    import opened DVN_Next_Invs_1_7
    import opened DVN_Next_Invs_8_18
    import opened DVN_Next_Invs_19_26
    import opened Fnc_Invs_1_26    
    import opened Fnc_Invs_27
    import opened Common_Proofs
    

    lemma {:axiom} axiom_inv37(
        dvn: DVState
    )    
    ensures inv37(dvn)

     

    
 
    

    
    
    

    

    
    

    

      
}