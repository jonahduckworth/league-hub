const {test} = require('node:test');
const assert = require('node:assert/strict');
const {canManageInfo, canReadInfo, canRevealInfo, containsScope, sameOrganization, validateScope} = require('../lib/infoCentreLogic');
const structure = {leagues: [{id:'l',name:'League'}], hubs:[{id:'h',leagueId:'l',name:'Hub'},{id:'other',leagueId:'l',name:'Other'}], teams:[{id:'t',hubId:'h',leagueId:'l',name:'Team'}]};
const item = {id:'item',orgId:'org',leagueId:'l',hubId:'h',teamId:'t',title:'Resource',status:'published',audience:'members',passwordAudience:'management',revision:1};
for (const role of ['platformOwner','superAdmin','managerAdmin','staff']) {
  const actor = {id:'u',role,orgId:'org',isActive:true,hubIds:['h'],teamIds:['t']};
  test(`${role}: resource, draft and password permissions`, () => {
    assert.equal(canReadInfo(actor,item,structure),true);
    assert.equal(canReadInfo({...actor,isActive:false},item,structure),false);
    assert.equal(canReadInfo({...actor,orgId:'foreign'},item,structure),role==='platformOwner');
    assert.equal(canReadInfo(actor,{...item,status:'draft'},structure),role!=='staff');
    assert.equal(canReadInfo(actor,{...item,status:'draft'},structure,true),false);
    assert.equal(canReadInfo(actor,{...item,status:'archived'},structure),false);
    assert.equal(canManageInfo(actor,item),role!=='staff');
    assert.equal(canRevealInfo(actor,item,structure),role!=='staff');
    assert.equal(canRevealInfo(actor,{...item,passwordAudience:'members'},structure),true);
    assert.equal(canReadInfo(actor,{...item,audience:'management'},structure),role!=='staff');
  });
}
test('staff membership derives hub/league through authoritative team parent',()=>{
  const actor={id:'u',role:'staff',orgId:'org',isActive:true,teamIds:['t']};
  assert.equal(canReadInfo(actor,{...item,teamId:null},structure),true);
  assert.equal(canReadInfo(actor,{...item,hubId:null,teamId:null},structure),true);
  assert.equal(canReadInfo(actor,{...item,hubId:'other',teamId:null},structure),false);
});
test('team managers cannot author hub or league resources or move outside scope',()=>{
  const actor={id:'u',role:'managerAdmin',isActive:true,teamIds:['t'],hubIds:[]};
  assert.equal(canManageInfo(actor,item),true);
  assert.equal(canManageInfo(actor,{...item,teamId:null}),false);
  assert.equal(canManageInfo(actor,{...item,hubId:'other',teamId:'other-team'}),false);
  assert.equal(canManageInfo(actor,{...item,hubId:null,teamId:null}),false);
  assert.equal(sameOrganization(actor,'org'),false);
});
test('scope hierarchy rejects mismatched hub, league and parent section',()=>{
  assert.equal(validateScope(item,structure),true);
  assert.equal(validateScope({...item,hubId:'other'},structure),false);
  assert.equal(validateScope({...item,hubId:null},structure),false);
  assert.equal(containsScope({leagueId:'l',hubId:null,teamId:null},item),true);
  assert.equal(containsScope({...item,teamId:null},item),true);
  assert.equal(containsScope({...item,hubId:'other',teamId:null},item),false);
});
