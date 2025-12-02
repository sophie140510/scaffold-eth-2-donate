"use client";

import { useMemo, useState } from "react";
import { Address as AddressDisplay } from "@scaffold-ui/components";
import type { NextPage } from "next";
import { formatUnits, parseUnits } from "viem";
import type { Address as ViemAddress } from "viem";
import { useAccount } from "wagmi";
import { useScaffoldReadContract, useScaffoldWriteContract, useTargetNetwork } from "~~/hooks/scaffold-eth";

const numberFormatter = new Intl.NumberFormat("en-US", {
  maximumFractionDigits: 2,
});

const StatCard = ({ title, value, helper }: { title: string; value: string; helper?: string }) => (
  <div className="rounded-2xl bg-base-200 border border-base-300 p-4 shadow-sm flex flex-col gap-1">
    <p className="text-sm text-neutral">{title}</p>
    <p className="text-2xl font-bold text-base-content">{value}</p>
    {helper && <p className="text-xs text-neutral">{helper}</p>}
  </div>
);

const Modal = ({
  open,
  title,
  children,
  onClose,
}: {
  open: boolean;
  title: string;
  children: React.ReactNode;
  onClose: () => void;
}) => {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4">
      <div className="w-full max-w-lg rounded-2xl bg-base-100 p-6 shadow-xl space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xl font-semibold">{title}</h3>
          <button className="btn btn-ghost btn-sm" onClick={onClose}>
            Close
          </button>
        </div>
        {children}
      </div>
    </div>
  );
};

const formRow = "flex flex-col gap-2";
const labelClass = "text-sm font-medium";
const inputClass = "input input-bordered w-full";

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const { targetNetwork } = useTargetNetwork();

  const { data: usdcBalance } = useScaffoldReadContract({
    contractName: "USDC",
    functionName: "balanceOf",
    args: [connectedAddress as ViemAddress | undefined],
    query: { enabled: Boolean(connectedAddress) },
  });

  const { data: doughBalance } = useScaffoldReadContract({
    contractName: "DOUGH",
    functionName: "balanceOf",
    args: [connectedAddress as ViemAddress | undefined],
    query: { enabled: Boolean(connectedAddress) },
  });

  const { data: protocolStats } = useScaffoldReadContract({
    contractName: "DoughHub",
    functionName: "getProtocolStats",
  });

  const { data: aaveStats } = useScaffoldReadContract({
    contractName: "DoughHub",
    functionName: "getAaveData",
  });

  const { data: redeemableStats } = useScaffoldReadContract({
    contractName: "DoughHub",
    functionName: "getRedeemableBreakdown",
  });

  const { data: owner } = useScaffoldReadContract({
    contractName: "DoughHub",
    functionName: "owner",
  });

  const { data: governance } = useScaffoldReadContract({
    contractName: "DoughHub",
    functionName: "governance",
  });

  const [depositModal, setDepositModal] = useState(false);
  const [redeemModal, setRedeemModal] = useState(false);
  const [burnModal, setBurnModal] = useState(false);
  const [depositAmount, setDepositAmount] = useState("");
  const [redeemAmount, setRedeemAmount] = useState("");
  const [burnAmount, setBurnAmount] = useState("");

  const { writeContractAsync: writeDoughHub, isMining: doughHubMining } = useScaffoldWriteContract({
    contractName: "DoughHub",
  });
  const { writeContractAsync: writeDough, isMining: doughMining } = useScaffoldWriteContract({
    contractName: "DOUGH",
  });
  const { writeContractAsync: writeStrategy } = useScaffoldWriteContract({ contractName: "StrategySplitter" });
  const { writeContractAsync: writeTreasury } = useScaffoldWriteContract({ contractName: "TreasurySplitter" });

  const [strategyRecipients, setStrategyRecipients] = useState("");
  const [strategyWeights, setStrategyWeights] = useState("");
  const [treasuryRecipients, setTreasuryRecipients] = useState("");
  const [treasuryWeights, setTreasuryWeights] = useState("");
  const [slippageBps, setSlippageBps] = useState("50");
  const [dexPath, setDexPath] = useState("");

  const isAdmin = useMemo(() => {
    if (!connectedAddress) return false;
    return (
      owner?.toLowerCase() === connectedAddress.toLowerCase() ||
      governance?.toLowerCase() === connectedAddress.toLowerCase()
    );
  }, [connectedAddress, governance, owner]);

  const parsedProtocolStats = useMemo(() => {
    if (!protocolStats) return null;
    const [tvl, minted, pendingRewards, treasuryBalance] = protocolStats as readonly [bigint, bigint, bigint, bigint];
    return {
      tvl: numberFormatter.format(Number(formatUnits(tvl, 18))),
      minted: numberFormatter.format(Number(formatUnits(minted, 18))),
      pendingRewards: numberFormatter.format(Number(formatUnits(pendingRewards, 18))),
      treasuryBalance: numberFormatter.format(Number(formatUnits(treasuryBalance, 18))),
    };
  }, [protocolStats]);

  const parsedAaveStats = useMemo(() => {
    if (!aaveStats) return null;
    const [apy, supplied, borrowed] = aaveStats as readonly [bigint, bigint, bigint];
    return {
      apy: numberFormatter.format(Number(formatUnits(apy, 2))),
      supplied: numberFormatter.format(Number(formatUnits(supplied, 18))),
      borrowed: numberFormatter.format(Number(formatUnits(borrowed, 18))),
    };
  }, [aaveStats]);

  const parsedRedeemableStats = useMemo(() => {
    if (!redeemableStats) return null;
    const [redeemable, nonRedeemable, treasury] = redeemableStats as readonly [bigint, bigint, bigint];
    return {
      redeemable: numberFormatter.format(Number(formatUnits(redeemable, 18))),
      nonRedeemable: numberFormatter.format(Number(formatUnits(nonRedeemable, 18))),
      treasury: numberFormatter.format(Number(formatUnits(treasury, 18))),
    };
  }, [redeemableStats]);

  const formattedUsdc = useMemo(() => numberFormatter.format(Number(formatUnits(usdcBalance ?? 0n, 6))), [usdcBalance]);
  const formattedDough = useMemo(
    () => numberFormatter.format(Number(formatUnits(doughBalance ?? 0n, 18))),
    [doughBalance],
  );

  const parseAddressList = (value: string) => value.split(/[\s,]+/).filter(Boolean) as ViemAddress[];
  const parseWeights = (value: string) =>
    value
      .split(/[\s,]+/)
      .filter(Boolean)
      .map(weight => BigInt(weight));

  const handleDeposit = async () => {
    if (!depositAmount) return;
    await writeDoughHub({
      functionName: "depositAndMint",
      args: [parseUnits(depositAmount, 6)],
    });
    setDepositAmount("");
    setDepositModal(false);
  };

  const handleRedeem = async () => {
    if (!redeemAmount) return;
    await writeDoughHub({
      functionName: "redeemAndWithdraw",
      args: [parseUnits(redeemAmount, 18)],
    });
    setRedeemAmount("");
    setRedeemModal(false);
  };

  const handleBurn = async () => {
    if (!burnAmount) return;
    await writeDough({
      functionName: "burn",
      args: [parseUnits(burnAmount, 18)],
    });
    setBurnAmount("");
    setBurnModal(false);
  };

  const handleStrategyUpdate = async () => {
    await writeStrategy({
      functionName: "updateRecipients",
      args: [parseAddressList(strategyRecipients), parseWeights(strategyWeights)],
    });
    setStrategyRecipients("");
    setStrategyWeights("");
  };

  const handleTreasuryUpdate = async () => {
    await writeTreasury({
      functionName: "updateRecipients",
      args: [parseAddressList(treasuryRecipients), parseWeights(treasuryWeights)],
    });
    setTreasuryRecipients("");
    setTreasuryWeights("");
  };

  const handleSlippageUpdate = async () => {
    await writeDoughHub({
      functionName: "setDexSlippageBps",
      args: [BigInt(slippageBps || "0")],
    });
  };

  const handlePathUpdate = async () => {
    await writeDoughHub({
      functionName: "setDexPath",
      args: [parseAddressList(dexPath)],
    });
    setDexPath("");
  };

  const handleHarvest = async () => {
    await writeDoughHub({ functionName: "harvest" });
  };

  const handleSwap = async () => {
    await writeDoughHub({ functionName: "swapRewards" });
  };

  const handleContribution = async () => {
    await writeDoughHub({ functionName: "contributeToTreasury" });
  };

  return (
    <div className="space-y-10 pb-20">
      <div className="flex flex-col gap-4 rounded-2xl bg-base-200 p-6 shadow-sm">
        <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="text-sm text-neutral">Treasury dashboard</p>
            <h1 className="text-3xl font-bold">DOUGH Control Center</h1>
          </div>
          <div className="flex flex-wrap gap-2 items-center">
            <p className="text-sm text-neutral">Connected</p>
            <AddressDisplay address={connectedAddress} chain={targetNetwork} />
          </div>
        </div>
        <div className="flex flex-wrap gap-3">
          <button className="btn btn-primary" onClick={() => setDepositModal(true)}>
            Deposit & Mint
          </button>
          <button className="btn" onClick={() => setRedeemModal(true)}>
            Redeem & Withdraw
          </button>
          <button className="btn btn-secondary" onClick={() => setBurnModal(true)}>
            Burn DOUGH
          </button>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="rounded-2xl bg-base-100 border border-base-300 p-6 shadow-sm space-y-4 lg:col-span-2">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold">Protocol stats</h2>
            <span className="badge badge-outline">Live</span>
          </div>
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <StatCard title="TVL" value={`$${parsedProtocolStats?.tvl ?? "0.00"}`} />
            <StatCard title="Minted DOUGH" value={parsedProtocolStats?.minted ?? "0.00"} helper="Total outstanding" />
            <StatCard title="Pending rewards" value={parsedProtocolStats?.pendingRewards ?? "0.00"} />
            <StatCard title="Treasury balance" value={parsedProtocolStats?.treasuryBalance ?? "0.00"} />
          </div>
          <div className="grid gap-4 md:grid-cols-3">
            <StatCard title="USDC Wallet" value={`${formattedUsdc} USDC`} />
            <StatCard title="DOUGH Wallet" value={`${formattedDough} DOUGH`} />
            <StatCard
              title="Redeemable Pool"
              value={parsedRedeemableStats?.redeemable ?? "0.00"}
              helper="Backing for outstanding DOUGH"
            />
          </div>
        </div>

        <div className="rounded-2xl bg-base-100 border border-base-300 p-6 shadow-sm space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold">Aave yield</h2>
            <span className="badge badge-outline">Strategy</span>
          </div>
          <div className="space-y-3">
            <StatCard title="Supply APY" value={`${parsedAaveStats?.apy ?? "0.00"}%`} />
            <div className="grid gap-3 sm:grid-cols-2">
              <StatCard title="Supplied" value={`${parsedAaveStats?.supplied ?? "0.00"} USDC`} />
              <StatCard title="Borrowed" value={`${parsedAaveStats?.borrowed ?? "0.00"} USDC`} />
            </div>
          </div>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-3">
        <StatCard
          title="Non-redeemable"
          value={parsedRedeemableStats?.nonRedeemable ?? "0.00"}
          helper="Protocol owned liquidity"
        />
        <StatCard title="Treasury" value={parsedRedeemableStats?.treasury ?? "0.00"} helper="Stability reserves" />
        <StatCard title="Redeemable" value={parsedRedeemableStats?.redeemable ?? "0.00"} helper="User withdrawable" />
      </div>

      {isAdmin && (
        <div className="rounded-2xl bg-base-100 border border-base-300 p-6 shadow-sm space-y-6">
          <div className="flex flex-col gap-2">
            <h2 className="text-xl font-semibold">Admin panel</h2>
            <p className="text-sm text-neutral">OWNER / GOVERNANCE controls for routing rewards and treasury flows.</p>
          </div>

          <div className="grid gap-6 lg:grid-cols-2">
            <div className="space-y-3">
              <h3 className="text-lg font-semibold">Strategy splitter</h3>
              <div className={formRow}>
                <label className={labelClass}>Recipients (comma or space separated)</label>
                <textarea
                  className="textarea textarea-bordered"
                  rows={2}
                  value={strategyRecipients}
                  onChange={e => setStrategyRecipients(e.target.value)}
                  placeholder="0xabc..., 0xdef..."
                />
              </div>
              <div className={formRow}>
                <label className={labelClass}>Weights (match recipients order)</label>
                <input
                  className={inputClass}
                  value={strategyWeights}
                  onChange={e => setStrategyWeights(e.target.value)}
                  placeholder="60 40"
                />
              </div>
              <button className="btn btn-primary" onClick={handleStrategyUpdate}>
                Update strategy splitter
              </button>
            </div>

            <div className="space-y-3">
              <h3 className="text-lg font-semibold">Treasury splitter</h3>
              <div className={formRow}>
                <label className={labelClass}>Recipients (comma or space separated)</label>
                <textarea
                  className="textarea textarea-bordered"
                  rows={2}
                  value={treasuryRecipients}
                  onChange={e => setTreasuryRecipients(e.target.value)}
                  placeholder="0xabc..., 0xdef..."
                />
              </div>
              <div className={formRow}>
                <label className={labelClass}>Weights (match recipients order)</label>
                <input
                  className={inputClass}
                  value={treasuryWeights}
                  onChange={e => setTreasuryWeights(e.target.value)}
                  placeholder="50 30 20"
                />
              </div>
              <button className="btn btn-primary" onClick={handleTreasuryUpdate}>
                Update treasury splitter
              </button>
            </div>
          </div>

          <div className="grid gap-6 lg:grid-cols-3">
            <div className="space-y-3">
              <h3 className="text-lg font-semibold">DEX routing</h3>
              <div className={formRow}>
                <label className={labelClass}>Slippage (bps)</label>
                <input
                  className={inputClass}
                  type="number"
                  min={0}
                  value={slippageBps}
                  onChange={e => setSlippageBps(e.target.value)}
                />
              </div>
              <button className="btn" onClick={handleSlippageUpdate}>
                Set slippage
              </button>
              <div className={formRow}>
                <label className={labelClass}>Path addresses</label>
                <input
                  className={inputClass}
                  value={dexPath}
                  onChange={e => setDexPath(e.target.value)}
                  placeholder="0xUSDC 0xWETH 0xDOUGH"
                />
              </div>
              <button className="btn" onClick={handlePathUpdate}>
                Update swap path
              </button>
            </div>

            <div className="space-y-3">
              <h3 className="text-lg font-semibold">Actions</h3>
              <div className="flex flex-col gap-2">
                <button className="btn btn-primary" onClick={handleHarvest}>
                  Harvest strategies
                </button>
                <button className="btn btn-secondary" onClick={handleSwap}>
                  Swap rewards
                </button>
                <button className="btn" onClick={handleContribution}>
                  Send to treasury
                </button>
              </div>
            </div>

            <div className="space-y-3">
              <h3 className="text-lg font-semibold">Status</h3>
              <StatCard title="Owner" value={owner ?? "-"} />
              <StatCard title="Governance" value={governance ?? "-"} />
              {(doughHubMining || doughMining) && <p className="text-sm text-warning">Pending transaction...</p>}
            </div>
          </div>
        </div>
      )}

      <Modal open={depositModal} onClose={() => setDepositModal(false)} title="Deposit USDC ➜ Mint DOUGH">
        <div className="space-y-3">
          <div className={formRow}>
            <label className={labelClass}>Amount (USDC)</label>
            <input
              className={inputClass}
              type="number"
              min={0}
              value={depositAmount}
              onChange={e => setDepositAmount(e.target.value)}
              placeholder="100"
            />
          </div>
          <button className="btn btn-primary w-full" onClick={handleDeposit}>
            Confirm deposit
          </button>
        </div>
      </Modal>

      <Modal open={redeemModal} onClose={() => setRedeemModal(false)} title="Redeem DOUGH ➜ Withdraw USDC">
        <div className="space-y-3">
          <div className={formRow}>
            <label className={labelClass}>Amount (DOUGH)</label>
            <input
              className={inputClass}
              type="number"
              min={0}
              value={redeemAmount}
              onChange={e => setRedeemAmount(e.target.value)}
              placeholder="10"
            />
          </div>
          <button className="btn btn-primary w-full" onClick={handleRedeem}>
            Confirm redemption
          </button>
        </div>
      </Modal>

      <Modal open={burnModal} onClose={() => setBurnModal(false)} title="Burn DOUGH">
        <div className="space-y-3">
          <div className={formRow}>
            <label className={labelClass}>Amount (DOUGH)</label>
            <input
              className={inputClass}
              type="number"
              min={0}
              value={burnAmount}
              onChange={e => setBurnAmount(e.target.value)}
              placeholder="5"
            />
          </div>
          <button className="btn btn-secondary w-full" onClick={handleBurn}>
            Burn tokens
          </button>
        </div>
      </Modal>
    </div>
  );
};

export default Home;
