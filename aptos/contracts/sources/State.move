module Wormhole::State{
    use 0x1::table::{Self, Table};
    use 0x1::event::{Self, EventHandle};
    use 0x1::signer::{address_of};
    use 0x1::string::{Self, String};
    use 0x1::vector::{Self};
    use 0x1::timestamp::{Self};
    use Wormhole::Structs::{Self, GuardianSet};

    friend Wormhole::Governance;
    friend Wormhole::Wormhole;
    
    struct GuardianSetChanged has store, drop{
        oldGuardianIndex: u64, //should be u32
        newGuardianIndex: u64, //should be u32
    } 
    
    struct WormholeMessage has store, drop{
        sender: address, 
        sequence: u64,  
        nonce: u64, //should be u32 
        payload: vector<u8>,
        consistencyLevel: u8,
    }   

    struct WormholeMessageHandle has key, store {
        event: EventHandle<WormholeMessage>
    }

    struct GuardianSetChangedHandle has key, store {
        event: EventHandle<GuardianSetChanged>
    }

	struct Provider has key, store{
        chainId: u64, // u16
		governanceChainId: u64, // U16
        governanceContract: vector<u8>, //bytes32
	}

    struct WormholeState has key{
        provider: Provider,

        // Mapping of guardian_set_index => guardian set
        guardianSets: Table<u64, GuardianSet>,

        // Current active guardian set index
        guardianSetIndex: u64,  //should be u32

        // Period for which a guardian set stays active after it has been replaced
        guardianSetExpiry: u64, //should be u32 - unused?

        // Sequence numbers per emitter
        sequences: Table<address, u64>,

        // Mapping of consumed governance actions
        consumedGovernanceActions: Table<vector<u8>, bool>,

        // Mapping of initialized implementations
        initializedImplementations: Table<address, bool>,

        messageFee: u128, //should be u256
    }

    //create some empty tables and stuff...
    public(friend) fun initWormholeState(admin: &signer){
        move_to(admin, WormholeState{
            provider:                   Provider {
                                            chainId: 0,
                                            governanceChainId: 0,
                                            governanceContract: vector::empty<u8>()
                                        },
            guardianSets:               table::new<u64, GuardianSet>(),
            guardianSetIndex:           0,
            guardianSetExpiry:          0,
            sequences:                  table::new<address, u64>(),
            consumedGovernanceActions:  table::new<vector<u8>, bool>(),
            initializedImplementations: table::new<address, bool>(),
            messageFee:                 0
        });
    }

    public fun createWormholeMessage(
        sender: address, 
        sequence: u64,  
        nonce: u64, //should be u32 
        payload: vector<u8>,
        consistencyLevel: u8
        ): WormholeMessage{
            WormholeMessage {
                sender:sender, 
                sequence:sequence, 
                nonce:nonce, 
                payload:payload, 
                consistencyLevel:consistencyLevel
            } 
    }

    public fun createWormholeMessageHandle(e: EventHandle<WormholeMessage>): WormholeMessageHandle{
        WormholeMessageHandle{
            event: e
        }
    }

    public fun createGuardianSetChangedHandle(e: EventHandle<GuardianSetChanged>): GuardianSetChangedHandle{
        GuardianSetChangedHandle{
            event: e
        }
    }

    public(friend) fun initMessageHandles(admin: &signer){
        move_to(admin, createWormholeMessageHandle(event::new_event_handle<WormholeMessage>(admin)));
        move_to(admin, createGuardianSetChangedHandle(event::new_event_handle<GuardianSetChanged>(admin)));
    }

    fun useSequence(emitter: address): u64 acquires WormholeState{
        let sequence = nextSequence(emitter);
        setNextSequence(emitter, sequence + 1);
        sequence
    }

    public fun publishMessage(
        sender: &signer,
        nonce: u64, //should be u32
        payload: vector<u8>,
        consistencyLevel: u8, 
    ) acquires WormholeState, WormholeMessageHandle{
        let addr = address_of(sender);
        let sequence = useSequence(addr);
        let event_handle = borrow_global_mut<WormholeMessageHandle>(@Wormhole);
        event::emit_event<WormholeMessage>(
            &mut event_handle.event,
            WormholeMessage {
                sender: addr,  
                sequence: sequence, 
                nonce: nonce,  
                payload: payload, 
                consistencyLevel: consistencyLevel, 
            }
        );
    }

    public(friend) fun updateGuardianSetIndex(newIndex: u64) acquires WormholeState { //should be u32
        let state = borrow_global_mut<WormholeState>(@Wormhole);
        state.guardianSetIndex = newIndex;
    }

    public(friend) fun expireGuardianSet(index: u64) acquires WormholeState{
        let state = borrow_global_mut<WormholeState>(@Wormhole);
        let guardianSet = table::borrow_mut<u64, GuardianSet>(&mut state.guardianSets, state.guardianSetIndex);
        Structs::expireGuardianSet(guardianSet);
    }    

    public(friend) fun storeGuardianSet(set: GuardianSet, index: u64) acquires WormholeState{ 
        let state = borrow_global_mut<WormholeState>(@Wormhole);
        table::add(&mut state.guardianSets, index, set);
    }

    // TODO: setInitialized?

    public(friend) fun setGovernanceActionConsumed(hash: vector<u8>) acquires WormholeState{
        let state = borrow_global_mut<WormholeState>(@Wormhole);
        table::add(&mut state.consumedGovernanceActions, hash, true);
    }

    public(friend) fun setChainId(chaindId: u64) acquires WormholeState{
        let state = borrow_global_mut<WormholeState>(@Wormhole);
        let provider = &mut state.provider;
        provider.chainId = chaindId;
    }

    public(friend) fun setGovernanceChainId(chainId: u64) acquires WormholeState{
        let state = borrow_global_mut<WormholeState>(@Wormhole);
        let provider = &mut state.provider;
        provider.governanceChainId = chainId;
    }
    
    public(friend) fun setGovernanceContract(governanceContract: vector<u8>) acquires WormholeState{
        let state = borrow_global_mut<WormholeState>(@Wormhole);
        let provider = &mut state.provider;
        provider.governanceContract = governanceContract;    
    }

    public(friend) fun setMessageFee(newFee: u128) acquires WormholeState{
        let state = borrow_global_mut<WormholeState>(@Wormhole);
        state.messageFee = newFee;
    }

    fun setNextSequence(emitter: address, sequence: u64) acquires WormholeState{
        let state = borrow_global_mut<WormholeState>(@Wormhole);
        if (table::contains(&state.sequences, emitter)){
            table::remove(&mut state.sequences, emitter);
        };
        table::add(&mut state.sequences, emitter, sequence);
    }

    // getters

    public fun nextSequence(emitter: address):u64 acquires WormholeState{ 
        let state = borrow_global_mut<WormholeState>(@Wormhole);
        *table::borrow(&state.sequences, emitter)
    }

    public fun getCurrentGuardianSetIndex():u64 acquires WormholeState{
        let state = borrow_global<WormholeState>(@Wormhole);
        state.guardianSetIndex
    }
    
    public fun getCurrentGuardianSet(): GuardianSet acquires WormholeState{
        let state = borrow_global<WormholeState>(@Wormhole);
        let ind = state.guardianSetIndex;
        *table::borrow(&state.guardianSets, ind)
    }
}