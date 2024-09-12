import Web3 from 'web3';
import {setGlobalState,getGlobalState} from "./store";
import abi from "./abis/DAO.json";

const {ethereum} =window;
window.web3 = new Web3(ethereum);
window.web3 = new Web3(window.web3.currentProvider);

const connectWallet = async() =>{
    try{
        if(!ethereum) return alert("Please install Metamask Extension in your browser");
        const accounts=await ethereum.request({method:"eth_requestAccounts"});
        setGlobalState('connectedAccount',accounts[0].toLowerCase());
    }
    catch(e){
        reportError(e);
    }
}

const isWalletConnected= async() =>{
    try{
        if(!ethereum) return alert("Please install metamask");
        const accounts = await ethereum.request({method:"eth_accounts"});

        window.ethereum.on('chainChanged',(chainId)=>{
            window.location.reload()
        });

        window.ethereum.on('accountsChanged',async()=>{
            setGlobalState('connectedAccount',accounts[0].toLowerCase());
            await isWalletConnected()
        });

        if(accounts.length){
            setGlobalState('connectedAccount',accounts[0].toLowerCase());
        }else {
            alert("Please connect Wallet.");
            console.log("No account found.");
        }
    }catch(e){
        reportError(e);
    }   
}

const getEthereumContract =async()=>{
    const connectedAccount=getGlobalState('connectedAccount')
    if(connectedAccount){
            const contract=new web3.eth.Contract(abi.abi,"0x5FbDB2315678afecb367f032d93F642f64180aa3");
            return contract
        } else {
        return getGlobalState('contract');
    }
}

const performContribute=async(amount) =>{
    try{
        amount=window.web3.utils.toWei(amount.toString(),'ether');
        const contract=await getEthereumContract();
        const account=getGlobalState('connectedAccount');
        await contract.method.contribute().sender({from:account,value:amount});

        window.location.reload();

    }catch(e){
        reportError(e);
        return e;
    }
}

const getInfo = async ()=>{
    try{
        if(!ethereum) return alert("Please install metamask");
        const contract=await getEthereumContract();
        const connectedAccount=getGlobalState('connectedAccount');
        const isStakeHolder=await contract.method.isStakeHolder()
            .call({from:connectedAccount});
        const balance=await contract.method.daoBalance()
        .call();
        const myBalance=await contract.methods
            .getBalance()
            .call({from:connectedAccount});
        setGlobalState('Balance',window.web3.utils.fromWei(balance));
        setGlobalState('myBalance',window.web3.utils.fromWei(myBalance));      
    }catch(e){
        reportError(e);
    }
}

const raiseProposal=async ({title,description,beneficiary,amount}) =>{
    try{
        amount=window.web3.utils.toWei(amount.toString(),'ether');
        const contract =await getEthereumContract();
        const account=getGlobalState('connectedAccount');

        await contract.methods
          .createProposal(title,description,amount)
          .send({from:account})

        window.location.reload();  
    }catch(e){
        reportError(e);
    }
}

const getProposals=async()=>{
    try{
        if(!ethereum) return alert("Please Install MetaMask");
        
        const contract =await getEthereumContract();
        const proposals=await contract.methods.getProposals().call();
        setGlobalState('proposals',structuredProposals(proposals));

    }catch(e){
        reportError(e)
    }
}

const structuredProposals=(proposals)=>{
    return proposals.map((proposal)=>({
        id:         proposal.id,
        amount:     window.web3.utils.fromWei(proposal.amount),
        title:     proposal.title,
        description:proposal.description,
        paid:proposal.paid,
        passed:proposal.passed,
        proposer:proposal.proposer,
        upVotes: Number(proposal.upVotes),
        downVotes:Number(proposal.downVotes),
        beneficiary:proposal.beneficiary,
        executor:proposal.executor,
        duration: proposal.duration
    }))
}

const getProposal=async(id)=>{
    try{
        const proposals=getGlobalState('proposals');
        return proposals.find((proposal)=>proposal.id==id);
    }catch(e){
        reportError(e);
    }
}

const voteOnProposal=async(proposalId,supported)=>{
    try{
        const contract =await getEthereumContract();
        const account=getGlobalState('connectedAccount');
        await contract.methods.Vote(proposalId,supported)
        .send({from:account});

        window.location.reload();
    }catch(e){
        reportError(e);
    }
}

const listVoters =async(id) =>{
    try {
        const contract =await getEthereumContract()
        const votes=await contract.methods.getsVotesOf(id).call();
        return votes;
    }catch(e){
        reportError(e);
    }
}

const payoutBeneficiary=async(id)=>{
    try {
        const contract =await getEthereumContract();
        const accounts=getGlobalState('connectedAccount')
        await contract.methods.payBeneficiary(id).send({from:account});
        window.location.relaod();
    }catch(e){
        reportError(e);
    }
}

const reportError=(e)=>{
    console.log(JSON.stringify(e),'red');
    throw new Error('No ethereum object,something is wrong');
}

export{
    isWalletConnected,
    connectWallet,
    performContribute,
    getInfo,
    raiseProposal,
    getProposals,
    getProposal,
    voteOnProposal,
    listVoters,
    payoutBeneficiary
}