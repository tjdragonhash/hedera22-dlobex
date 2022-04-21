# CONVERT SBG TO JPG USING LINUX

#!/bin/bash
for i in `ls *.svg`
do
export nfn=`basename -- $i .svg`
convert $i "./jpgs/"$nfn".jpg"
done


#!/bin/bash
for i in `ls *.svg`
do
export nfn=`basename -- $i .svg`
convert $i "./"$nfn".jpg"
done

# SMART CONTRACT DEPLOYMENT

https://rinkeby.etherscan.io/tx/0x78a790c14ec546fc76f1e30682f0472ccb81769ddef410927c890de8a48c898b

# BACKUP

        // sendEthButton.addEventListener('click', () => {
        //     const to = '0xA59B29d7dbC9794d1e7f45123C48b2b8d0a34636';
        //     const amount = '0x16345785D8A0000';

        //     console.log("from", accounts[0], "to", to, "for", amount);

        //     ethereum.request({
        //         method: 'eth_sendTransaction',
        //         params: [
        //             {
        //                 from: accounts[0],
        //                 to: to,
        //                 value: amount
        //             },
        //         ],})
        //         .then((txHash) => console.log(txHash))
        //         .catch((error) => console.error);
        // });

# STEP-BY-STEP DEPLOYMENT GUIDE

1. Generate all SVGs images
2. Run org.tj.t721.GenMetaData with the appropriate settings (Collection for OpenSea, Image reference, Attributes)
3. Upload the generated images + jsons to a site
4. Deploy the smart contract - get the address
5. Update the smart contract address + ABI in the index.htm
6. Upload index.htm