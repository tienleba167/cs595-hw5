use dep::std::merkle::compute_merkle_root;
use dep::std::hash::pedersen_hash;

fn main(
    id: Field,
    r: Field,
    oldPath: [Field; 8],
    oldRoot: pub Field,
    newRoot: pub Field,
    commitment: pub Field,
    leafIndex: pub Field
) {
    // 1. Create commitment
    let commitment_input: [Field; 2] = [id, r];
    let calc_commitment = pedersen_hash(commitment_input);
    assert(calc_commitment == commitment);

    // 2. Recompute old Merkle root
    let old_merkle_root = compute_merkle_root(0, leafIndex, oldPath);
    assert(old_merkle_root == oldRoot);

    // 3. Recompute new Merkle root
    let new_merkle_root = compute_merkle_root(commitment, leafIndex, oldPath);
    assert(new_merkle_root == newRoot);
}
