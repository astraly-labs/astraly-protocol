%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import deploy, get_contract_address
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math import split_felt

from openzeppelin.security.initializable.library import Initializable

from contracts.AstralyAccessControl import AstralyAccessControl

from immutablex.starknet.token.erc721_token_metadata.interfaces.IERC721_Token_Metadata import (
    IERC721_Token_Metadata,
)
@contract_interface
namespace IAstralySBTContractFactory {
    func getFossilFactsRegistryAddress() -> (address: felt) {
    }

    func isDeployed(address: felt) -> (yes_no: felt) {
    }
}

@storage_var
func SBT_badge_class_hash() -> (hash: felt) {
}

@storage_var
func deployed_badge_contracts_address(token_address: felt, block_number: felt, balance: felt) -> (
    address: felt
) {
}
@storage_var
func badge_contracts(address: felt) -> (deployed: felt) {
}

@storage_var
func fossil_facts_registry_address() -> (address: felt) {
}

@event
func SBTContractCreated(
    contract_address: felt, block_number: felt, balance: felt, token_address: felt
) {
}

@event
func SBTClassHashChanged(new_class_hash: felt) {
}

@view
func isDeployed{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    badge_address: felt
) -> (yes_no: felt) {
    let (deployed: felt) = badge_contracts.read(badge_address);
    return (deployed,);
}

@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _SBT_badge_class_hash: felt, admin_address: felt, _fossil_facts_registry_address: felt
) {
    with_attr error_message("Class hash cannot be zero") {
        assert_not_zero(_SBT_badge_class_hash);
    }

    with_attr error_message("Invalid admin address") {
        assert_not_zero(admin_address);
    }

    with_attr error_message("Invalid Facts Registry address") {
        assert_not_zero(_fossil_facts_registry_address);
    }

    Initializable.initialize();
    AstralyAccessControl.initializer(admin_address);
    SBT_badge_class_hash.write(_SBT_badge_class_hash);
    fossil_facts_registry_address.write(_fossil_facts_registry_address);
    return ();
}

@external
func setFossilFactsRegistryAddress{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_address: felt
) {
    AstralyAccessControl.assert_only_owner();
    with_attr error_message("Invalid Facts Registry address") {
        assert_not_zero(new_address);
    }
    fossil_facts_registry_address.write(new_address);
    return ();
}

@external
func setSBTBadgeClassHash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_class_hash: felt
) {
    AstralyAccessControl.assert_only_owner();

    with_attr error_message("Invalid new class hash") {
        assert_not_zero(new_class_hash);
    }

    SBT_badge_class_hash.write(new_class_hash);
    SBTClassHashChanged.emit(new_class_hash);
    return ();
}

// token_address can be 0 in case of eth
@external
func createSBTContract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    block_number: felt, balance: felt, token_address: felt, tokenURI_len: felt, tokenURI: felt*
) -> (new_SBT_badge_contract_address: felt) {
    alloc_locals;
    AstralyAccessControl.assert_only_owner();

    let (already_deployed: felt) = deployed_badge_contracts_address.read(
        token_address, block_number, balance
    );
    with_attr error_message("Already deployed") {
        assert already_deployed = FALSE;
    }

    assert_not_zero(block_number);
    let (token_id: Uint256) = _felt_to_uint(1);
    let (class_hash: felt) = SBT_badge_class_hash.read();
    let (salt: felt) = get_contract_address();
    let (facts_registry_address: felt) = fossil_facts_registry_address.read();
    let (calldata: felt*) = alloc();
    assert calldata[0] = block_number;
    assert calldata[1] = balance;
    assert calldata[2] = token_address;
    assert calldata[3] = tokenURI_len;
    memcpy(calldata + 4, tokenURI, tokenURI_len);
    assert calldata[4 + tokenURI_len] = facts_registry_address;
    let (new_SBT_badge_contract_address: felt) = deploy(
        class_hash=class_hash,
        contract_address_salt=salt,
        constructor_calldata_size=5 + tokenURI_len,
        constructor_calldata=calldata,
        deploy_from_zero=0,
    );
    %{ print(ids.new_SBT_badge_contract_address) %}
    IERC721_Token_Metadata.setTokenURI(
        new_SBT_badge_contract_address, token_id, tokenURI_len, tokenURI
    );
    deployed_badge_contracts_address.write(
        token_address, block_number, balance, new_SBT_badge_contract_address
    );
    badge_contracts.write(new_SBT_badge_contract_address, TRUE);
    SBTContractCreated.emit(new_SBT_badge_contract_address, block_number, balance, token_address);
    return (new_SBT_badge_contract_address,);
}
func _felt_to_uint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value: felt
) -> (value: Uint256) {
    let (high, low) = split_felt(value);
    tempvar res: Uint256;
    res.high = high;
    res.low = low;
    return (res,);
}
