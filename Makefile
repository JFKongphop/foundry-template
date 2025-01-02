ifeq (,$(wildcard .env))
  $(error .env file not found)
endif
include .env

deploy:
	forge script script/${c}.s.sol --broadcast --verify --rpc-url $(HOLESKY) 

testAdmin:
	forge test --match-path test/Contract.t.sol -${v}

