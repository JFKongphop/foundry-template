mt:
	forge test --match-path test/MyToken.t.sol -vvvvv

BOI := BOI/

bid:
	forge test --match-path test/${BOI}bid.t.sol -$(t)

be:
	forge test --match-path test/${BOI}bidEvent.t.sol -$(t)

bt:
	forge test --match-path test/${BOI}buyToken.t.sol -${t}

star:
	forge test --via-ir --match-path test/${BOI}sendTokensAndRefund.t.sol -${t}

wd:
	forge test --match-path test/${BOI}withdraw.t.sol -${t}

wda:
	forge test --match-path test/${BOI}withdrawAmount.t.sol -${t}

ff:
	forge test --via-ir --match-path test/${BOI}finalFlow.t.sol -${t}


ifeq (,$(wildcard .env))
  $(error .env file not found)
endif
include .env

dp:
	forge script script/${c}.s.sol --broadcast --rpc-url $(HOLESKY)
	
dpvf:
	forge script script/${c}.s.sol --broadcast --verify --rpc-url $(HOLESKY)
