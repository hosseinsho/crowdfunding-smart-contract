// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract OwnerShip {
    address public owner;
    
    constructor (){
        owner = msg.sender;
    }
    modifier isOnlyOwner {
        require(msg.sender == owner, "must be owner");
        _;
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////////



contract Pausable is OwnerShip {
  event Pause();
  event Unpause();

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() isOnlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() isOnlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }
}




/////////////////////////////////////////////////////////////////////////////////////////////////////



contract CrowdFunding is OwnerShip, Pausable{

    Project public project;
    Contribution[] public contributions;
    mapping(address => uint) public contribution;
   
    enum Status {
        Fundraising,
        Fail,
        Successful
    }
    
    event LogProjectInitialized (
        address owner,
        string name,
        string website,
        uint minimumToRaise,
        uint maximumToRaise,
        uint duration
    );
    event ProjectSubmitted(address addr, string name, string url, bool initialized);
    event LogFundingReceived(address addr, uint amount, uint currentTotal);
    event LogProjectPaid(address projectAddr, uint amount, Status status);
    event Refund(address _to, uint amount);
    event LogErr (address addr, uint amount);
    // here 
    
    struct Contribution {
        address addr;
        uint amount;
    }

    struct Project {
        address addr;
        string name;
        string website;
        uint minimumToRaise;
        uint maximumToRaise;
        uint currentBalance;
        uint deadline;
        uint completeAt;
        Status status;
    }
    
    constructor (address project_owner, uint _minimumToRaise, uint _maximumToRaise, uint _durationProjects,
        string memory _name, string memory _website) public payable {
        super;
        uint minimumToRaise = _minimumToRaise * 1 ether; //convert to wei
        uint maximumToRaise = _maximumToRaise * 1 ether; //convert to wei

        uint deadlineProjects = block.timestamp + _durationProjects* 1 days;
        project = Project(project_owner, _name, _website, minimumToRaise, maximumToRaise, 0, deadlineProjects, 0, Status.Fundraising);
        // todo read
        emit LogProjectInitialized(
            project_owner,
            _name,
            _website,
            _minimumToRaise,
            _maximumToRaise,
            _durationProjects);
    }

    modifier atStage(Status _status) {
        require(project.status == _status,"Only matched status allowed." );
        _;
    }

    modifier onlyProjectOwner() {
        require(project.addr == msg.sender,"Only Project Owner Allowed." );
        _;
    }

    modifier afterDeadline() {
        require( block.timestamp >= project.deadline, "need to wait until the deadline come");
        _;
    }

    modifier atEndOfCampain() {
        require(!((project.status == Status.Fail || project.status == Status.Successful) && project.completeAt + 1 seconds <  block.timestamp));
        _;
    }
    modifier recieveMaxAmount(){
        require(project.currentBalance <= project.maximumToRaise, "you pay more than maximum amount of project fund rising");
        _;
    }
    // 4,175,558,158,089,600 Wei now about 10 dollor
    modifier moreThanLittle(){
        require(msg.value  > 4175558158089600 * 1 wei, "not enough amount for funding");
        _;
    }

    function fund() public atStage(Status.Fundraising) recieveMaxAmount whenNotPaused moreThanLittle payable {
        contribution[msg.sender] += msg.value;
        contributions.push(
            Contribution({
                addr: msg.sender,
                amount: msg.value
                })
            );
        project.currentBalance += msg.value;
        emit LogFundingReceived(msg.sender, msg.value, project.currentBalance);
    }
    // todo Contribution datatype
    // todo owner and accessibilities
    // add afterDeadline
    function checkGoalReached() public onlyProjectOwner payable{
        
        if (project.currentBalance > project.minimumToRaise){
            payable(project.addr).transfer(project.currentBalance);
            project.status = Status.Successful;
            emit LogProjectPaid(project.addr, project.currentBalance, project.status);
        }
        else {
            project.status = Status.Fail;
            // todo here
            for (uint i = 0; i < contributions.length; ++i) {
              uint amountToRefund = contributions[i].amount;
              if(!payable(contributions[i].addr).send(contributions[i].amount)) {
                contributions[i].amount = amountToRefund;
                emit LogErr(contributions[i].addr, contributions[i].amount);
                revert();
              } else{
                project.currentBalance -= contributions[i].amount;
                emit Refund(contributions[i].addr, contributions[i].amount);
              }
            }
        }
        project.completeAt = block.timestamp;
    }
    
    function destroy() public isOnlyOwner {
        pause();
    }
}
