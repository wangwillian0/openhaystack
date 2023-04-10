use p224::{SecretKey, PublicKey, ecdh::diffie_hellman};

const PRIVATE_LEN : usize = 28;
const PUBLIC_LEN : usize = 57;

pub fn ecdh(public_key_blob : Vec<u8>, private_key : Vec<u8>) -> Vec<u8> {
    let num_keys = public_key_blob.len() / PUBLIC_LEN;
    let mut vec_shared_secret = vec![0u8; num_keys*PRIVATE_LEN];

    let private_key = SecretKey::from_slice(&private_key).unwrap();
    let secret_scalar = private_key.to_nonzero_scalar();
    
    let mut i = 0;
    let mut j = 0; 

    for _i in 0..num_keys {
        let public_key = PublicKey::from_sec1_bytes(&public_key_blob[i..i+PUBLIC_LEN]).unwrap();
        let public_affine = public_key.as_affine();
        
        let shared_secret = diffie_hellman(secret_scalar, public_affine);  
        let shared_secret_ref = shared_secret.raw_secret_bytes().as_ref();


        vec_shared_secret[j..j+PRIVATE_LEN].copy_from_slice(shared_secret_ref);

        i += PUBLIC_LEN;
        j += PRIVATE_LEN;
    }
    
    return vec_shared_secret;
}
