pragma solidity ^0.4.8;

contract Randao {
  struct Participant {
      uint256   secret;		//随机数
      uint256   reward;		//奖励
	  //uint256	number;		//编号
      bool      partaken;   //是否已经参与过
	  bool 		rewarded;	//是否奖励
  }
  
  struct Consumer {			//活动发起者 
    address caddr;			//地址
    uint256 bountypot;		//奖金池
  }

  struct Campaign {			//活动
      uint32    bnum;		//截至时间
      uint96    deposit;	//押金
	  
      uint256   campaignshash;//活动块hash，用于计算那些人参与随机运算    
	  uint256	target;		//目标参与人数
	  uint256	number;		//实际参与者人数
      uint256   random;		//随机数
      uint256   bountypot;	//奖金
	  bool      settled;	//产生随机数是否成功
      mapping (uint256 => uint256) secret;//随机数种子集合
      mapping (address => Consumer) consumers;		//发起者
      mapping (address => Participant) participants;//参与者
  }
  uint256 public numCampaigns;		//活动数
  Campaign[] public campaigns;		//活动数组
  //address public founder;
  uint256 public flag;
  uint256 public numCombination = 12;
  function newCampaign(				//创建活动
      uint32 _bnum,
      uint96 _deposit,
	  uint256 _target
  ) payable returns (uint256 _campaignID) {
      _campaignID = campaigns.length++;
      Campaign c = campaigns[_campaignID];
      numCampaigns++;
	  c.target=_target;
      c.bnum = _bnum;
      c.deposit = _deposit;
      c.campaignshash = uint(block.blockhash(block.number-1));
      //campaignshash = c.campaignshash;
      c.bountypot = msg.value;
      c.consumers[msg.sender] = Consumer(msg.sender, msg.value);
  }
  
  modifier checkDeposit(uint256 _deposit) { if (msg.value != _deposit) throw; _; } //检查押金
  modifier checkTime(uint256 _bnum){if (block.number >_bnum) throw; _;}			   //检查提交时间
  modifier beFalse(bool _t) { if (_t) throw; _; }									//判断是否为假

  //参与者提交随机数
  function commit(uint256 _campaignID, uint256 _s)  external payable {
      Campaign c = campaigns[_campaignID];
      commitmentCampaign(_campaignID, _s, c);
  } 
  
  //随机数提交到活动
  function commitmentCampaign(
      uint256 _campaignID,
      uint256 _s,
      Campaign storage c
	  //Campaign c
  ) checkDeposit(c.deposit)
    checkTime(c.bnum)
    beFalse(c.participants[msg.sender].partaken)
   	internal {
      c.number++;
	  uint256 num=c.number;
      c.secret[num]=_s;
	  //c.number++; 
      //c.participants[msg.sender] = Participant(_s,0,num,true,false);
      c.participants[msg.sender] = Participant(_s,0,true,false);
	  //c.random +=_s;
  }
  
  
  //是否为发起者
   modifier beConsumer(address _caddr) {
      if (_caddr != msg.sender) throw;
      _;
  } 
  //提交随机数是否结束
  modifier bountyPhase(uint256 _bnum){ if (block.number <= _bnum) throw; _; }
  //检查是否达到目标参与者人数
  modifier checkTarget(uint256 _target,uint256 _num) {if(_num < _target) throw; _;}
  //获取随机数  
  function getRandom(uint256 _campaignID) external returns (uint256) {
      Campaign c = campaigns[_campaignID];
      return returnRandom(c);
  }


	// 计算阶乘
	function countFactorial(uint256 natural)
		returns(uint256) {
            uint256 factorial = 1;
		//if (natural == 0 && natural == 1)
			//return factorial;
		
		for (uint256 i = 1; i <= natural; i++) {
			factorial *= i;
		}
		return factorial;
	}

	// 计算组合数
	function countCelected (uint256 numParticipant, uint256 numSelected)  internal
		returns(uint256) {
        uint256 temp1 = countFactorial(numParticipant);
        uint256 temp2 = countFactorial(numSelected)*countFactorial(numParticipant - numSelected);
		//numCombination = countFactorial(numParticipant) / (countFactorial(numSelected)*countFactorial(numParticipant - numSelected));
		numCombination = temp1/temp2;
        return numCombination;
	}


	// 计算选中的参与者排列
	function selectedCombination(uint256 numParticipant, uint256 numSelected, uint256 blockHash/*, uint256 numCombination*/)
		returns(uint256) {
		uint256 newHash = blockHash % numCombination;
		uint256 countNo = 0; // 当前组合序号
		bool[] memory selected = new bool[](numParticipant); // 创建长度为numParticipant的bool型数组
        uint256 selectedResult = 0;
		// 将前m个数置1，作为初始条件
		uint256 i = 0;
		for (i = 0; i < numSelected; i++) {
			selected[i] = true;
		}
		bool bFind = false;
		do {
			for (i = 0; i < numParticipant; i++) {
				selectedResult *= 2;
				if (selected[i]) 
					selectedResult += 1;
			}
			if (newHash == countNo) {
				return selectedResult;
				break;
			}
			selectedResult = 0; // 进行下一次组合前结果清0
			bFind = false;
			for (i = 0; i < numParticipant - 1; i++) {
				if (selected[i] && !selected[i + 1]) {
					// 交换10为01
					selected[i] = false;
					selected[i + 1] = true;
					bFind = true;
					// 如果第一位为0，则将第i位置之前的1移到最左边，如为1则第i位置之前的1就在最左边，无需移动
					if (!selected[0]) {
						uint256 j =0;
						for (uint256 k = 0; k < i; k++) {
							if (selected[k]) {
							    selected[k] = selected[j];
								selected[j] = true;
								j++;
							}
						}
					}
					break;
				}
			}
			countNo++;
		} while (bFind);
		//ends
	}


	// 判断是否被选中
function whetherSelected(uint256 numParticipant, uint256 numSelected,uint256 selectedResult)
		returns(bool) {
		uint256 b = selectedResult >>(numParticipant - numSelected)& 1;
		if(b == 1)
			return true;
		else
			return false;
	}

  function returnRandom(Campaign storage c)
  bountyPhase(c.bnum)
  beConsumer(c.consumers[msg.sender].caddr)
  internal returns (uint256) {
          c.settled = true;
          //numCombination = 12;
          //numCombination=countCelected(c.number,c.target);//计算组合数
          uint256 selectedResult=selectedCombination(c.number,c.target,c.campaignshash);
          //selectedResult = 12;
          flag=numCombination;
          //flag=selectedResult;
          for(uint256 i=1;i<=c.number;i++){
              if(whetherSelected(c.number,i,selectedResult))
                    c.random=c.random+c.secret[i];
          }
          return c.random;
  }
   
  //获取奖金
  function getMyBounty(uint256 _campaignID) external {
      Campaign c = campaigns[_campaignID];
      Participant p = c.participants[msg.sender];
      transferBounty(c, p);
  }
  function transferBounty(
      Campaign storage c,
      Participant storage p
    ) bountyPhase(c.bnum)
      beFalse(p.rewarded) internal {
	  uint256 share;
      if (c.settled) {
              share = c.bountypot/c.number;
              returnReward(share, c, p);
      } else {
	  	  	share = c.bountypot/(10*c.number);
         	returnReward(share, c, p);
      }
  }

  function returnReward(
      uint256 _share,
      Campaign storage c,
      Participant storage p
  ) internal {
      p.reward = _share;
      p.rewarded = true;
      if (!msg.sender.send(_share + c.deposit)) {
          p.reward = 0;
          p.rewarded = false;
      }
  }

  //如果生成随机送失败发起者返回部分赏金
  function refundBounty(uint256 _campaignID) external {
      Campaign c = campaigns[_campaignID];
      returnBounty(_campaignID, c);
  }

  function returnBounty(uint256 _campaignID, Campaign storage c)
    bountyPhase(c.bnum)
    beConsumer(c.consumers[msg.sender].caddr) internal {     
	  if(c.settled)
      	c.consumers[msg.sender].bountypot = 0;
	  else
	  	c.consumers[msg.sender].bountypot = (9*bountypot)/10;
	  uint256 bountypot = c.consumers[msg.sender].bountypot;
      if (!msg.sender.send(bountypot)) {
          c.consumers[msg.sender].bountypot = bountypot;
      }
  }
 }
 
