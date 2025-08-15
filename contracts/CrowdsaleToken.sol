// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IERC20Extended.sol";

/**
 * @title CrowdsaleToken
 * @dev 众筹平台的ERC20代币合约
 * 
 * 特性：
 * - 标准ERC20功能
 * - 铸币功能（仅限授权地址）
 * - 燃烧功能
 * - 暂停机制
 * - 角色权限控制
 * - 最大供应量限制
 * - 重入攻击保护
 */
contract CrowdsaleToken is 
ERC20, 
ERC20Burnable, 
ERC20Pausable, 
AccessControl,
ReentrancyGuard,
IERC20Extended {
    
     // 角色定义
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // 代币参数
    uint256 private _maxSupply;
    
    // 统计信息
    uint256 public totalMinted;
    uint256 public totalBurned;
   
    // 铸币历史记录
    mapping(address => uint256) public mintedBy;
    mapping(address => uint256) public burnedFrom;

    /**
     * @dev 构造函数，初始化代币合约
     * @param name 代币名称
     * @param symbol 代币符号
     * @param maxSupply_ 最大供应量
     * @param admin 超级管理员地址
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 maxSupply_,
        address admin
    ) ERC20(name, symbol) {
        require(maxSupply_ > 0, "Max supply must be greater than 0");
        require(admin != address(0), "CrowdsaleToken: Admin address cannot be zero");

        _maxSupply = maxSupply_;

        //_grantRole 是 OpenZeppelin AccessControl.sol 中的函数，用于授予角色
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);

        // 不在构造函数中铸造代币，保留铸造能力给后续使用
        // 代币将在CrowdsaleFactory部署时按需铸造

        emit MaxSupplyUpdated(0, maxSupply_);
    }




    /**
     * @dev 铸币函数，仅限授权地址调用
     * @param to 接收代币的地址
     * @param amount 要铸造的代币数量
     */
    function mint(address to, uint256 amount) 
        external
        override
        onlyRole(MINTER_ROLE)
        nonReentrant
    {
        require(to != address(0), "CrowdsaleToken: Mint to the zero address");
        require(amount > 0, "CrowdsaleToken: Mint amount must be greater than 0");
        require(canMint(amount), "CrowdsaleToken: mint amount exceeds max supply");
        
        totalMinted += amount;
        //_msgSender() 是 OpenZeppelin Context.sol 中的函数，返回当前调用者地址
        mintedBy[_msgSender()] += amount;

        _mint(to, amount);

        emit TokenMinted(to, amount, _msgSender());
        
    }

     /**
     * @dev 批量铸造代币
     * @param recipients 接收地址数组
     * @param amounts 铸造数量数组
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyRole(MINTER_ROLE)
        nonReentrant
    {
        require(recipients.length == amounts.length, "CrowdsaleToken: arrays length mismatch");
        require(recipients.length > 0, "CrowdsaleToken: empty arrays");
        require(recipients.length <= 100, "CrowdsaleToken: batch size too large");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(canMint(totalAmount), "CrowdsaleToken: batch minting would exceed max supply");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "CrowdsaleToken: mint to zero address");
            require(amounts[i] > 0, "CrowdsaleToken: mint amount must be greater than 0");
            
            _mint(recipients[i], amounts[i]);
            emit TokenMinted(recipients[i], amounts[i], _msgSender());
        }

        totalMinted += totalAmount;
        mintedBy[_msgSender()] += totalAmount;
    }

    /**
     * @dev 燃烧指定地址的代币
     * @param from 燃烧地址
     * @param amount 燃烧数量
     */
    function burnFrom(address from, uint256 amount) 
        public 
        override(ERC20Burnable, IERC20Extended)
        onlyRole(BURNER_ROLE) 
        nonReentrant 
    {
        require(from != address(0), "CrowdsaleToken: burn from zero address");
        require(amount > 0, "CrowdsaleToken: burn amount must be greater than 0");

        totalBurned += amount;
        burnedFrom[from] += amount;

        super.burnFrom(from, amount);

        emit TokenBurned(from, amount, _msgSender());
    }


     /**
     * @dev 暂停所有代币转账
     */
    function pause() external override onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev 恢复所有代币转账
     */
    function unpause() external override onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev 重写 paused 函数以解决多重继承冲突
     */
    function paused() public view override(Pausable, IERC20Extended) returns (bool) {
        return super.paused();
    }


  /**
     * @dev 更新最大供应量（仅能减少）
     * @param newMaxSupply 新的最大供应量
     */
    function updateMaxSupply(uint256 newMaxSupply) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newMaxSupply >= totalSupply(), "CrowdsaleToken: new max supply less than current supply");
        require(newMaxSupply < _maxSupply, "CrowdsaleToken: can only decrease max supply");

        uint256 oldMaxSupply = _maxSupply;
        _maxSupply = newMaxSupply;

        emit MaxSupplyUpdated(oldMaxSupply, newMaxSupply);
    }

     /**
     * @dev 获取最大供应量
     */
    function maxSupply() external view override returns (uint256) {
        return _maxSupply;
    }

     /**
     * @dev 检查是否可以铸造指定数量
     * @param amount 计划铸造数量
     */
    function canMint(uint256 amount) public view override returns (bool) {
        return totalSupply() + amount <= _maxSupply;
    }

      /**
     * @dev 获取剩余可铸造数量
     */
    function remainingMintable() external view returns (uint256) {
        return _maxSupply - totalSupply();
    }


    /**
     * @dev 获取代币统计信息
     */
    function getTokenStats() external view returns (
        uint256 currentSupply,
        uint256 maxSupply_,
        uint256 totalMinted_,
        uint256 totalBurned_,
        uint256 remainingMintable_,
        bool isPaused
    ) {
        return (
            totalSupply(),
            _maxSupply,
            totalMinted,
            totalBurned,
            _maxSupply - totalSupply(),
            paused()
        );
    }


     /**
     * @dev 检查地址是否有指定角色
     */
    function hasRole(bytes32 role, address account) 
        public 
        view 
        override(AccessControl) 
        returns (bool) 
    {
        return super.hasRole(role, account);
    }


    // 重写必要的函数以支持暂停功能
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }

    /**
     * @dev 支持接口检查
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IERC20Extended).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
