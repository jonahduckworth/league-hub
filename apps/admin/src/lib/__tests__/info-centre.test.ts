import { describe, expect, it } from 'vitest';
import { canManageInfoScope, infoItemInHub, type InfoData } from '../info-centre';
import type { AppUser, UserRole } from '../types';
const data: InfoData={structure:{leagues:[{id:'l',name:'League'}],hubs:[{id:'h',name:'Hub',leagueId:'l'}],teams:[]},sections:[],entries:[],policies:[]};
describe('Info Centre scopes',()=>{
  it.each(['platformOwner','superAdmin','managerAdmin','staff'] as UserRole[])('%s has bounded management access',(role)=>{
    const user={role,isActive:true,hubIds:['h'],teamIds:['t']} as AppUser;
    expect(canManageInfoScope(user,{leagueId:'l',hubId:'h',teamId:'t'})).toBe(role!=='staff');
    expect(canManageInfoScope({...user,isActive:false},{leagueId:'l',hubId:'h',teamId:null})).toBe(false);
    expect(canManageInfoScope(user,{leagueId:'l',hubId:'other',teamId:null})).toBe(role==='platformOwner'||role==='superAdmin');
  });
  it('includes shared league resources in a selected hub',()=>{
    expect(infoItemInHub({leagueId:'l',hubId:null,teamId:null},'h',data)).toBe(true);
    expect(infoItemInHub({leagueId:'l',hubId:'other',teamId:null},'h',data)).toBe(false);
  });
});
