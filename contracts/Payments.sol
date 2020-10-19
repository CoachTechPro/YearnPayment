pragma solidity ^0.7.3;

import "./erc721/ERC721.sol"; 

interface IERC20 {
	function totalSupply() external view returns (uint256);
	function balanceOf(address account) external view returns (uint256);
	function transfer(address recipient, uint256 amount) external returns (bool);
	function allowance(address owner, address spender) external view returns (uint256);
	function approve(address spender, uint256 amount) external returns (bool);
	function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
	using SafeMath for uint256;
	using Address for address;

	function safeTransfer(IERC20 token, address to, uint256 value) internal {
		callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
	}

	function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
		callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
	}

	function safeApprove(IERC20 token, address spender, uint256 value) internal {
		require((value == 0) || (token.allowance(address(this), spender) == 0),
			"SafeERC20: approve from non-zero to non-zero allowance"
		);
		callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
	}
	function callOptionalReturn(IERC20 token, bytes memory data) private {
		require(address(token).isContract(), "SafeERC20: call to non-contract");

		// solhint-disable-next-line avoid-low-level-calls
		(bool success, bytes memory returndata) = address(token).call(data);
		require(success, "SafeERC20: low-level call failed");

		if (returndata.length > 0) { // Return data is optional
			// solhint-disable-next-line max-line-length
			require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
		}
	}
}

contract YearnPayment is ERC721("Yearn Payment", "yPay") {
	using SafeMath for uint256;

	struct Payment {
		uint256	value;
		uint256	interval;
		uint256	bonus;
		uint256	lastUpdate;
		bool	valid;
	}

	Payment[] payments;

	address public treasury = address(0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52);
	address public controller;
	IERC20 constant public yUSD = IERC20(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);

	mapping(address => bool) authorised;

	contructor (address _treasury) {
		controller = msg.sender;
		authorised[controller] = true;
	}

	modifier onlyController() {
		require(msg.sender == controller, "YearnPayment: Not controller");
		_;
	}

	modifier onlyAuthorised() {
		require(authorised[msg.sender] || msg.sender == controller, "YearnPayment: Not authorised");
		_;
	}

	function transferOwnership(address _newController) public onlyController {
		controller = _newController;
	}

	function changeTreasury(address _newTreasury) public onlyController {
		treasury = _newTreasury;
	}

	function addAuthorisedUser(address _user) public onlyController {
		authorised[_user] = true;
	}
	
	function removeAuthorisedUser(address _user) public onlyController {
		authorised[_user] = false;
	}

	function createRecurringPayment(uint256 _value, uint256 _days, address _receiver) public onlyAuthorised {
		uint256 _id = gifts.length;
		Payment memory _payment = Payment(_value, _days days, 0, block.timestamp, true);
		payments.push(_payment);
		_safeMint(_receiver, _id);
	}

	function revokePayment(uint _tokenId) public onlyAuthorised {
		require(_tokenId < payments.length, "YearnPayment: Token does not exist.")
		Payment storage _payment = payments[_tokenId];
		_payment.valid = false;
	}

	function ratifyPayment(uint _tokenId) public onlyAuthorised {
		require(_tokenId < payments.length, "YearnPayment: Token does not exist.")
		Payment storage _payment = payments[_tokenId];
		_payment.valid = true;
	}

	function modifyPaymentValue(uint _tokenId, uint256 _newValue) public onlyAuthorised {
		require(_tokenId < payments.length, "YearnPayment: Token does not exist.")
		Payment storage _payment = payments[_tokenId];
		_payment.value = _newValue;
	}

	function modifyPaymentInterval(uint _tokenId, uint256 _newDays) public onlyAuthorised {
		require(_tokenId < payments.length, "YearnPayment: Token does not exist.")
		Payment storage _payment = payments[_tokenId];
		_payment.interval = _newDays days;
	}

	function addOneTimebonus(uint _tokenId, uint256 _bonus) public onlyAuthorised {
		require(_tokenId < payments.length, "YearnPayment: Token does not exist.")
		Payment storage _payment = payments[_tokenId];
		_payment.bonus = _bonus;
	}

	function claim(uint _tokenId) public {
		require(ownerOf(_tokenId) == msg.sender, "YearnPayment: Not owner of token.");
		Payment storage _payment = payments[_tokenId];
		require(_payment.valid, "YearnPayment: Payment NFT not valid");
		require(block.timestamp >= _payment.lastUpdate + _payment.interval, "YearnPayment: Too soon to claim payment.");
		uint256 _pay = _payment.value.add(_payment.bonus);
		_payment.lastUpdate = block.timestamp;
		_payment.bonus = 0;
		yUSD.safeTransferFrom(treasury, msg.sender, _pay);
	}
}