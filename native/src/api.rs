use p224::{SecretKey, PublicKey, ecdh::diffie_hellman};
use rayon::prelude::*;
use std::sync::{Arc, Mutex};

const PRIVATE_LEN : usize = 28;
const PUBLIC_LEN : usize = 57;

pub fn ecdh(public_key_blob : Vec<u8>, private_key : Vec<u8>) -> Vec<u8> {
    let num_keys = public_key_blob.len() / PUBLIC_LEN;
    let vec_shared_secret = Arc::new(Mutex::new(vec![0u8; num_keys*PRIVATE_LEN]));

    let private_key = SecretKey::from_slice(&private_key).unwrap();
    let secret_scalar = private_key.to_nonzero_scalar();

    (0..num_keys).into_par_iter().for_each(|i| {
        let start = i * PUBLIC_LEN;
        let end = start + PUBLIC_LEN;
        let public_key = PublicKey::from_sec1_bytes(&public_key_blob[start..end]).unwrap();
        let public_affine = public_key.as_affine();

        let shared_secret = diffie_hellman(secret_scalar, public_affine);
        let shared_secret_ref = shared_secret.raw_secret_bytes().as_ref();

        let start = i * PRIVATE_LEN;
        let end = start + PRIVATE_LEN;

        let mut vec_shared_secret = vec_shared_secret.lock().unwrap();
        vec_shared_secret[start..end].copy_from_slice(shared_secret_ref);
    });

    Arc::try_unwrap(vec_shared_secret).unwrap().into_inner().unwrap()
}
