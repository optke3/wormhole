module Wormhole::Structs{

    struct Signature has key, store, copy, drop{
        signature: vector<u8>, 
        guardianIndex: u64, 
	}

    struct Guardian has key, store, drop, copy{
        key:       vector<u8>,
    }

    struct GuardianSet has key, store, copy, drop {
        index:     u64, 
        guardians: vector<Guardian>,
        //expirationTime: u64, //u32
    }

    public fun createGuardian(key: vector<u8>): Guardian{
        Guardian{
            key: key
        }
    }

    public fun createGuardianSet(index: u64, guardians: vector<Guardian>): GuardianSet{
        GuardianSet{
            index: index, 
            guardians: guardians,
        }
    }

    public fun unpackSignature(s: &Signature): (vector<u8>, u64){
        (s.signature,  s.guardianIndex)
    }

    public fun createSignature(s: vector<u8>, guardianIndex: u64): Signature{
        Signature{
            signature:      s, 
            guardianIndex:  guardianIndex,
        }
    }

    public fun getKey(guardian: Guardian): vector<u8>{
        guardian.key
    }
    
    public fun getGuardianSetIndex(guardianSet: GuardianSet): u64{
        guardianSet.index
    }

    public fun getGuardians(guardianSet: GuardianSet): vector<Guardian>{
        guardianSet.guardians
    }

} 