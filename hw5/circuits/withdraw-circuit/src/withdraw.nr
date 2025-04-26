use dep::std::merkle::compute_merkle_root;
use dep::std::hash::pedersen_hash;

fn main(
    r: Field,
    leafIndex: pub Field,
    path: [Field; 8],
    root: pub Field,
    id: pub Field
) {
    // 1. Recompute commitment
    let commitment_input: [Field; 2] = [id, r];
    let calc_commitment = pedersen_hash(commitment_input);

    // 2. Recompute Merkle root from commitment
    let merkle_root = compute_merkle_root(calc_commitment, leafIndex, path);

    // 3. Enforce root correctness
    assert(merkle_root == root);
}
