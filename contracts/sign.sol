// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.0;

library Signatures {

    function splitSignature(bytes memory sig)
       public
       pure
       returns (uint8, bytes32, bytes32)
   {
       require(sig.length == 65, "Not the expected 65 bytes!");
       bytes32 r;
       bytes32 s;
       uint8 v;

       assembly {
           // first 32 bytes, after the length prefix
           r := mload(add(sig, 32))
           // second 32 bytes
           s := mload(add(sig, 64))
           // final byte (first byte of the next 32 bytes)
           v := byte(0, mload(add(sig, 96)))
       }

       return (v, r, s);
   }

   function recoverSigner(bytes32 message, bytes memory sig) public pure returns(address) {
       uint8 v;
       bytes32 r;
       bytes32 s;
       (v, r, s) = splitSignature(sig);
       return ecrecover(message, v, r, s);
  }
}