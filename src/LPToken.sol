// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LPToken
 * @dev LP Token 合约，用于代表 AMM 池子中的流动性份额
 * @author NFT DEX Team
 */
contract LPToken is ERC20, Ownable {
    /**
     * @dev 构造函数
     * @param name LP Token 名称
     * @param symbol LP Token 符号
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) Ownable(msg.sender) {}
    
    /**
     * @dev 铸造 LP Token（仅所有者可调用）
     * @param to 接收者地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev 销毁 LP Token（仅所有者可调用）
     * @param from 持有者地址
     * @param amount 销毁数量
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
    
    /**
     * @dev 批量转移 LP Token（仅所有者可调用）
     * @param from 发送者地址
     * @param to 接收者地址
     * @param amount 转移数量
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        override 
        returns (bool) 
    {
        // 如果是所有者调用，允许转移（用于流动性移除）
        if (msg.sender == owner()) {
            _transfer(from, to, amount);
            return true;
        }
        
        // 否则使用标准的 transferFrom
        return super.transferFrom(from, to, amount);
    }
    
    /**
     * @dev 批量转移 LP Token（仅所有者可调用）
     * @param from 发送者地址
     * @param to 接收者地址
     * @param amount 转移数量
     */
    function batchTransfer(address from, address to, uint256 amount) 
        external 
        onlyOwner 
    {
        _transfer(from, to, amount);
    }
}
