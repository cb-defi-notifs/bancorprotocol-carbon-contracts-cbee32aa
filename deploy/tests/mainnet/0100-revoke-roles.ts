import { AccessControlEnumerableUpgradeable } from '../../../components/Contracts';
import { DeployedContracts, isLive, describeDeployment } from '../../../utils/Deploy';
import { Roles } from '../../../utils/Roles';
import { expect } from 'chai';
import { getNamedAccounts } from 'hardhat';

describeDeployment(
    __filename,
    () => {
        let deployer: string;
        let daoMultisig: string;

        beforeEach(async () => {
            ({ deployer, daoMultisig } = await getNamedAccounts());
        });

        it('should revoke deployer roles', async () => {
            // get contracts
            const carbon = (await DeployedContracts.CarbonController.deployed()) as AccessControlEnumerableUpgradeable;
            const voucher = (await DeployedContracts.Voucher.deployed()) as AccessControlEnumerableUpgradeable;
            const carbonVortex =
                (await DeployedContracts.CarbonVortex.deployed()) as AccessControlEnumerableUpgradeable;

            // expect dao multisig to have the admin role for all contracts
            expect(await carbon.hasRole(Roles.Upgradeable.ROLE_ADMIN, daoMultisig)).to.be.true;
            expect(await voucher.hasRole(Roles.Upgradeable.ROLE_ADMIN, daoMultisig)).to.be.true;
            expect(await carbonVortex.hasRole(Roles.Upgradeable.ROLE_ADMIN, daoMultisig)).to.be.true;

            // expect deployer not to have the admin role for any contracts
            expect(await carbon.hasRole(Roles.Upgradeable.ROLE_ADMIN, deployer)).to.be.false;
            expect(await voucher.hasRole(Roles.Upgradeable.ROLE_ADMIN, deployer)).to.be.false;
            expect(await carbonVortex.hasRole(Roles.Upgradeable.ROLE_ADMIN, deployer)).to.be.false;

            // expect deployer not to have the fee manager role
            expect(await carbon.hasRole(Roles.CarbonController.ROLE_FEES_MANAGER, deployer)).to.be.false;
        });
    },

    { skip: isLive }
);
