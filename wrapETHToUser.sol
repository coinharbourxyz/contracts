// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

interface IWETH9 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract WrapETH {
    address public constant WETH9 = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; // WETH9 contract on Sepolia

    // Wrap ETH into WETH and transfer to caller
    function wrapETH() external payable {
        require(msg.value > 0, "Must send ETH to wrap");

        // Wrap ETH into WETH
        IWETH9(WETH9).deposit{value: msg.value}();

        // Transfer WETH to the caller
        require(
            IWETH9(WETH9).transfer(msg.sender, msg.value),
            "WETH transfer failed"
        );
    }

    // // Unwrap WETH from caller's balance and send ETH back to caller
    // function unwrapWETH(uint256 amount) external {
    //     require(amount > 0, "Amount must be greater than 0");

    //     // Transfer WETH from the caller to the contract
    //     require(
    //         IWETH9(WETH9).transferFrom(msg.sender, address(this), amount),
    //         "WETH transfer failed"
    //     );

    //     // Unwrap WETH to ETH
    //     IWETH9(WETH9).withdraw(amount);

    //     // Send ETH back to the caller
    //     (bool success, ) = msg.sender.call{value: amount}("");
    //     require(success, "ETH transfer failed");
    // }

    // Check WETH balance of caller
    function getWETHBalance() external view returns (uint256) {
        // Access the WETH balance using the ERC20 balanceOf function
        (bool success, bytes memory data) = WETH9.staticcall(
            abi.encodeWithSignature("balanceOf(address)", msg.sender)
        );
        require(success, "Failed to read WETH balance");
        return abi.decode(data, (uint256));
    }

    receive() external payable {}

    fallback() external payable {}
}
