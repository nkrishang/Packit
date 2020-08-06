// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./sign.sol";
import "@nomiclabs/buidler/console.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";

contract Market  {

    string check = "Works";
    //================= Data Structures for the contract ==============

    struct Vault {
        bytes signature;
        bytes32 hashValue;

        bool vendorSent;
        bool customerReceived;
    }

    struct Transaction {
        uint timeStamp;

        address to;
        address from;

        uint price;
        uint collateral;

        Vault vault;
    }

    struct Asset {
        bool owner;

        bool forSale;
        uint price;
        uint collateral;

        bytes32 assetID;
    }


    // User(Customer) => assetID => Transaction receipt
    mapping(address => mapping(bytes32 => Transaction)) private purchases;

    // User(Vendor) => assetID => Owned assets
    mapping(address => mapping(bytes32 => Asset)) private assetList;

    // Asset Ownership map
    mapping(bytes32 => address) public ownershipRecord;



    //==================== Test functions =================

    function getAssetOwner(bytes32 _assetID) external view returns(address) {
        return ownershipRecord[_assetID];
    }

    function getTransactionRecipient(address customer, bytes32 _assetID) external view returns(address){
        return purchases[customer][_assetID].to;
    }

    function getVendorSignature(address customer, bytes32 _assetID) external view returns(bytes memory) {
        return purchases[customer][_assetID].vault.signature;
    }

    function getVendorSent(address customer, bytes32 _assetID) external view returns(bool) {
        return purchases[customer][_assetID].vault.vendorSent;
    }

    function verifyOwnershipTransfer(address vendor, bytes32 _assetID) external view returns(bool) {
        return assetList[vendor][_assetID].owner;
    }

    function getCustomerReceived(address customer, bytes32 _assetID) external view returns(bool){
        return purchases[customer][_assetID].vault.customerReceived;
    }
    //==================== Asset Onboarding ===============

     function _registerAsset(address _owner, bool _forSale, uint _price, uint _collateral,  bytes32 _assetID) private {

        Asset memory newAsset = Asset({
            owner: true,
            forSale: _forSale,
            price: _price,
            collateral: _collateral,
            assetID: _assetID
        });

        assetList[_owner][_assetID] = newAsset;
        ownershipRecord[_assetID] = _owner;
    }

    function registerAsset(bool _forSale, uint _price, uint _collateral, bytes32 _assetID) external {
        _registerAsset(msg.sender, _forSale, _price, _collateral, _assetID);
    }



    //==================== Making a purchase ========================

    function generateVault() private pure returns(Vault memory) {

        Vault memory newVault = Vault({
            signature: "",
            hashValue: "",

            vendorSent: false,
            customerReceived: false
        });

        return newVault;
    }


    function _transactionReceipt(address _to, address _from, uint _price, uint _collateral, bytes32 _assetID) private {

        Vault memory _vault = generateVault();

        Transaction memory receipt = Transaction({
            timeStamp: block.timestamp,

            to: _to,
            from: _from,

            price: _price,
            collateral: _collateral,

            //canWithdraw: User.Null,
            vault: _vault
        });

        bytes32 temp_hashValue = keccak256(abi.encode(_to, _from, _price, _collateral, _assetID));
        bytes32 _hashValue = ECDSA.toEthSignedMessageHash(temp_hashValue);
        receipt.vault.hashValue = _hashValue;

        purchases[_from][_assetID] = receipt;
    }


    function purchase(address _to, bytes32 _assetID) external payable {
        Asset memory targetAsset = assetList[_to][_assetID];

        require(msg.value == targetAsset.price + targetAsset.collateral, "Incorrect amount for purchase.");
        require(targetAsset.forSale, "The asset is not available to be purchashed.");

        targetAsset.forSale = false;

        address _from = msg.sender;
        uint _price = targetAsset.price;
        uint _collateral = targetAsset.collateral;

        _transactionReceipt(_to, _from, _price, _collateral, _assetID);
    }


    //==================== Handling the sale ==========================

    function getAssetHash(address customer, bytes32 _assetID) external view returns(bytes32) {
        require(assetList[msg.sender][_assetID].owner, "You do not own this asset.");

        return purchases[customer][_assetID].vault.hashValue;
    }

    function initiateSale(address customer, bytes32 _assetID,  bytes calldata _signature) external {
        require(assetList[msg.sender][_assetID].owner == true, "You do not own this asset.");

        purchases[customer][_assetID].vault.signature = _signature;
        purchases[customer][_assetID].vault.vendorSent = true;
    }

    function verifySale(bytes32 _assetID, bytes32 _hashValue) external {

        require(purchases[msg.sender][_assetID].vault.vendorSent, "Something has gone wrong. Hash received through invalid means.");

        Transaction memory receipt = purchases[msg.sender][_assetID];

        bytes memory vendorSignature = receipt.vault.signature;
        address _vendor = receipt.to;

        address recoveredAddr = ECDSA.recover(_hashValue, vendorSignature);

        console.log(recoveredAddr);

        if(recoveredAddr == _vendor) {

            assetList[_vendor][_assetID].owner = false;
            ownershipRecord[_assetID] = msg.sender;

            purchases[msg.sender][_assetID].vault.customerReceived = true;
        }
    }

    function withdrawCustomer(bytes32 _assetID) external payable {
        require(block.timestamp - purchases[msg.sender][_assetID].timeStamp > 1 days, "You must give the vendor a day to respond.");

        Transaction memory receipt = purchases[msg.sender][_assetID];

        if(!(receipt.vault.vendorSent)) {

            msg.sender.transfer(receipt.price + receipt.collateral);

        } else if (receipt.vault.vendorSent) {

            require(receipt.vault.customerReceived, "You must acknowledge the sale to withdraw your collateral");
            msg.sender.transfer(receipt.collateral);
        }
    }

    function withdrawVendor(address customer, bytes32 _assetID) external payable {

        Transaction memory receipt = purchases[customer][_assetID];
        require(receipt.vault.customerReceived, "Please wait for the customer to acknowledge sale.");

        msg.sender.transfer(receipt.price);
    }

}
