# Repository Cleanup Checklist

## 🔍 Review Date: December 30, 2024

---

## 📂 FILES TO DELETE

### 1. **Deprecated Configuration Files** ⚠️
- [ ] `script/config/TestnetConfig.sol`
  - **Reason**: Marked as deprecated in file comments
  - **Note**: "Use environment variables instead" - functionality moved to .env
  - **Impact**: SAFE - No longer referenced by any scripts

### 2. **Old Deployment Files** ⚠️
- [ ] `deployments/unknown.json`
  - **Reason**: Contains localhost addresses (local test deployment)
  - **Content**:
    ```
    poolManager: 0x5FbDB2315678afecb367f032d93F642f64180aa3
    hook: 0x2eb1CDAE6311cEfe2D2bfF060AFa82a60Dd9A0C0
    ```
  - **Impact**: SAFE - Not the current deployment

### 3. **Temporary Log Files** ✅
- [ ] `deployment.log`
  - **Reason**: Temporary output from deployment script
  - **Impact**: SAFE - Can be regenerated

- [ ] `test-results.log`
  - **Reason**: Temporary test output
  - **Impact**: SAFE - Can be regenerated

### 4. **Old Broadcast History** (Optional) ⚠️
- [ ] `broadcast/DeployTestnet.s.sol/8453/` (entire directory)
  - **Reason**: Failed deployment to Base Mainnet (chain 8453)
  - **Impact**: SAFE - Historical data only

- [ ] Old timestamped broadcasts in `broadcast/DeployTestnet.s.sol/84532/`:
  - [ ] `run-1766855976.json`
  - [ ] `run-1766856100.json`
  - [ ] `run-1766857447.json`
  - [ ] `run-1767114281927.json`
  - **Reason**: Old deployments, superseded by latest
  - **Keep**: `run-latest.json` and most recent timestamped file
  - **Impact**: SAFE - Historical data only

- [ ] Old broadcasts in `broadcast/TestBaseSepolia.s.sol/84532/`:
  - [ ] `run-1767116061171.json`
  - **Keep**: `run-latest.json`
  - **Impact**: SAFE - Historical data only

### 5. **Cache Files** (Optional) ℹ️
- [ ] `cache/DeployTestnet.s.sol/84532/run-*.json` (old ones)
- [ ] `cache/TestBaseSepolia.s.sol/84532/run-*.json` (old ones)
  - **Reason**: Cached deployment data, regenerated on each run
  - **Keep**: `run-latest.json` files
  - **Impact**: SAFE - Will be regenerated

- [ ] `cache/solidity-files-cache.json`
  - **Reason**: Forge compilation cache
  - **Impact**: SAFE - Will be regenerated on next build

### 6. **Unused Scripts** (Verify First) ⚠️
- [ ] `script/SetupLocal.s.sol`
  - **Reason**: Appears to be for local anvil setup only
  - **Note**: Check if you use local development
  - **Impact**: MEDIUM - Verify you don't need local testing first

### 7. **Node Modules** ❓
- [ ] `node_modules/` directory
  - **Reason**: Unclear why npm packages are in blockchain folder
  - **Contains**: @openzeppelin/contracts (npm version)
  - **Note**: You're using Foundry (forge), not npm for Solidity
  - **Impact**: VERIFY - Check if any scripts depend on this

---

## 📝 FILES TO UPDATE

### 1. **Documentation with Old Addresses** 🔧
Need to update these files to use new deployment addresses:

#### `TEST_COMMANDS.md`
- [ ] Update old addresses to new ones:
  - OLD Hook: `0x4641d2DEB741D2422D97E56a5559598501fc20c0`
  - OLD TokenManager: `0x4eeDf1b397DB6419a50B7f3B9F0688058f4F66c9`
  - OLD Collateral: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
  - **NEW addresses**: Use from `deployments/base-sepolia.json`

#### `TESTING.md`
- [ ] Update "Current Deployment" section with new addresses
- [ ] Remove references to old collateral token

#### `DEPLOYMENT_GUIDE.md`
- [ ] Update example .env with new addresses
- [ ] Update deployment address examples

#### `README_TESTING.md`
- [ ] Update comparison table with new addresses

### 2. **Environment File Consolidation** 🔧
- [ ] Review `env.example` vs root documentation
  - **Files**:
    - `env.example` (969 bytes)
    - `.env.example` (not found - might need to create)
  - **Action**: Ensure there's one clear `.env.example` for users

- [ ] Check `env.local` file
  - **Purpose**: Unknown
  - **Action**: Determine if needed or can be deleted

### 3. **Main README** 📖
- [ ] `README.md` - Verify it's up to date with:
  - [ ] New integration (Hook ↔ TokenManager)
  - [ ] New deployment addresses
  - [ ] Latest testing instructions

---

## 📚 DOCUMENTATION CONSOLIDATION

### Potential Duplicates/Overlap

#### Testing Documentation:
- `TESTING.md` (root)
- `TEST_COMMANDS.md` (root)
- `README_TESTING.md` (root)
- `documentation/TESTING.md`
- `documentation/QUICKSTART.md`

**Recommendation**:
- [ ] Compare content and consolidate if overlapping
- [ ] Keep:
  - `README_TESTING.md` - Quick start
  - `TESTING.md` - Comprehensive guide
  - `TEST_COMMANDS.md` - Command reference
- [ ] Consider merging `documentation/` folder content into main docs

#### Architecture Documentation:
- `documentation/ARCHITECTURE.md`
- `INTEGRATION_COMPLETE.md`
- `WORK_SUMMARY.md`

**Recommendation**:
- [ ] Move `INTEGRATION_COMPLETE.md` and `WORK_SUMMARY.md` to `documentation/`
- [ ] OR create a single comprehensive ARCHITECTURE.md

---

## ✅ CLEANUP ACTIONS SUMMARY

### High Priority (Safe to Delete):
1. ✅ `script/config/TestnetConfig.sol` - Deprecated
2. ✅ `deployments/unknown.json` - Old local deployment
3. ✅ `deployment.log` - Temporary log
4. ✅ `test-results.log` - Temporary log

### Medium Priority (Review First):
5. ⚠️ Old broadcast files (keep latest only)
6. ⚠️ `script/SetupLocal.s.sol` - If not using local dev
7. ⚠️ Old cache files

### Low Priority (Investigate):
8. ❓ `node_modules/` - Why does this exist?
9. ❓ `env.local` - Purpose unclear

### Documentation Updates Needed:
10. 🔧 Update old addresses in all .md files
11. 🔧 Consolidate duplicate documentation
12. 🔧 Update main README.md

---

## 🎯 RECOMMENDED CLEANUP ORDER

### Phase 1: Quick Wins (SAFE)
```bash
# Delete deprecated files
rm script/config/TestnetConfig.sol
rm deployments/unknown.json
rm deployment.log
rm test-results.log

# Delete failed Base Mainnet deployment
rm -rf broadcast/DeployTestnet.s.sol/8453/
```

### Phase 2: History Cleanup (SAFE - Optional)
```bash
# Keep only latest broadcast files
cd broadcast/DeployTestnet.s.sol/84532/
ls -t | tail -n +3 | xargs rm  # Keep 2 most recent

cd broadcast/TestBaseSepolia.s.sol/84532/
ls -t | tail -n +2 | xargs rm  # Keep 1 most recent
```

### Phase 3: Cache Cleanup (SAFE - Will Regenerate)
```bash
# Clean old cache
forge clean
# Or manually:
rm -rf cache/DeployTestnet.s.sol/84532/run-*.json
rm -rf cache/TestBaseSepolia.s.sol/84532/run-*.json
```

### Phase 4: Investigation Needed
```bash
# Check if node_modules is needed
# Review package.json if exists
# If not needed: rm -rf node_modules

# Check env.local purpose
# If not needed: rm env.local
```

### Phase 5: Documentation Updates
1. Update all addresses in docs to new deployment
2. Consolidate overlapping documentation
3. Move project docs to documentation/ folder
4. Update main README with latest info

---

## 📊 SPACE SAVINGS ESTIMATE

- Deprecated files: ~5 KB
- Log files: ~10 KB
- Old broadcasts: ~500 KB
- Old cache: ~200 KB
- node_modules: ~20 MB (if deleted)

**Total potential savings**: ~21 MB

---

## ⚠️ WARNINGS

1. **DO NOT DELETE**:
   - `deployments/base-sepolia.json` - Current deployment!
   - `broadcast/*/run-latest.json` - Current deployment records
   - Any `.env` file with real keys
   - `out/` directory - Compiled contracts

2. **BACKUP FIRST**:
   - Consider git commit before major cleanup
   - Keep one copy of old broadcast files if you might need transaction hashes

3. **VERIFY BEFORE DELETING**:
   - `node_modules/` - Check if any scripts use it
   - `SetupLocal.s.sol` - If you do local testing
   - `env.local` - Check purpose

---

## 🎯 FINAL RECOMMENDATION

**Safest Approach**:
1. Delete only obviously temporary files (logs)
2. Delete clearly deprecated files (TestnetConfig.sol)
3. Delete clearly wrong deployments (unknown.json, chain 8453)
4. Update documentation addresses
5. Let user decide on history/cache cleanup
6. Investigate node_modules before deleting

**After cleanup, repository will be**:
- ✅ Cleaner and more maintainable
- ✅ Less confusing for new developers
- ✅ Only current deployment information
- ✅ Up-to-date documentation

---

**Ready for your review and approval before any deletions! 🚀**
