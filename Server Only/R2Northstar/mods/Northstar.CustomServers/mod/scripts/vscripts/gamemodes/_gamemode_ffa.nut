global function FFA_Init

struct {
	//// CHANGE ME
	string score_leader_highlight = "enemy_boss_bounty" // highlight effect applied to person in 1st place
	string offhand_weapon = "mp_weapon_thermite_grenade" // offhand weapon

	bool reset_pulse_blade_cooldown_on_pulse_blade_kill = true

	int wme_kill_value = 10
	int offhand_kill_value = 10
	int reset_kill_value = 5
	int melee_kill_value = 5
	//// STOP CHANGING ME
} file

void function FFA_Init()
{
	SetShouldUseRoundWinningKillReplay( true )
	ClassicMP_ForceDisableEpilogue( true )
	SetLoadoutGracePeriodEnabled( false ) // prevent modifying loadouts with grace period
	SetWeaponDropsEnabled( false )
	Riff_ForceTitanAvailability( eTitanAvailability.Never )
	Riff_ForceBoostAvailability( eBoostAvailability.Disabled )

	AddCallback_OnPlayerKilled( OnPlayerKilled )
	AddCallback_OnPlayerRespawned( OnPlayerRespawned )
	AddCallback_GameStateEnter( eGameState.WinnerDetermined, OnWinnerDetermined )
}

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( victim != attacker && victim.IsPlayer() && attacker.IsPlayer() && GetGameState() == eGameState.Playing )
	{
		SetRoundWinningKillReplayAttacker(attacker)
		if ( DamageInfo_GetDamageSourceIdentifier( damageInfo ) == eDamageSourceId.mp_weapon_grenade_sonar || DamageInfo_GetDamageSourceIdentifier( damageInfo ) == eDamageSourceId.human_execution)
		{
			if (file.reset_pulse_blade_cooldown_on_pulse_blade_kill) 
			{
				attacker.TakeWeaponNow( "mp_weapon_grenade_sonar" ) // resets cooldown if you kill with it
				attacker.GiveOffhandWeapon( "mp_weapon_grenade_sonar", OFFHAND_LEFT )
			}
			
			EmitSoundOnEntityOnlyToPlayer( attacker, attacker, "UI_CTF_3P_TeamGrabFlag" )
			bankrupt(victim)

			AddTeamScore( attacker.GetTeam(), file.reset_kill_value )
			attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, file.reset_kill_value )
			attacker.AddToPlayerGameStat( PGS_TITAN_KILLS, 1 )
		} 
		else if ( DamageInfo_GetDamageSourceIdentifier( damageInfo ) == eDamageSourceId.melee_pilot_emptyhanded ) 
		{
			AddTeamScore( attacker.GetTeam(), file.melee_kill_value )
			attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, file.melee_kill_value )
		} 
		else if ( DamageInfo_GetDamageSourceIdentifier( damageInfo ) == eDamageSourceId.mp_weapon_wingman_n ) 
		{
			AddTeamScore( attacker.GetTeam(), file.wme_kill_value )
			attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, file.wme_kill_value )
		}
		else 
		{
			AddTeamScore( attacker.GetTeam(), file.offhand_kill_value )
			attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, file.offhand_kill_value )
		}

        if (attacker == GetWinningPlayer())
            SetHighlight( attacker )
	}
}

void function bankrupt(entity player) {
	while (GameRules_GetTeamScore(player.GetTeam()) > 0) {
		AddTeamScore( player.GetTeam(), -1 )
	}
	player.SetPlayerGameStat( PGS_ASSAULT_SCORE, 0)

	EmitSoundOnEntityOnlyToPlayer( player, player, "UI_InGame_MarkedForDeath_PlayerMarked" )
}

void function OnWinnerDetermined()
{
	SetRespawnsEnabled( false )
	SetKillcamsEnabled( false )
}

void function OnPlayerRespawned( entity player )
{
	foreach ( entity weapon in player.GetMainWeapons() )
		player.TakeWeaponNow( weapon.GetWeaponClassName() )
	
	foreach ( entity weapon in player.GetOffhandWeapons() )
		player.TakeWeaponNow( weapon.GetWeaponClassName() )
	
	array<string> mods = ["sns", "pas_fast_ads", "tactical_cdr_on_kill", "pas_run_and_gun", "pas_fast_swap"]
	player.GiveWeapon( "mp_weapon_wingman_n", mods)
	player.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE )
	player.GiveOffhandWeapon( file.offhand_weapon, OFFHAND_RIGHT )
	player.GiveOffhandWeapon( "mp_weapon_grenade_sonar", OFFHAND_LEFT )

    if (player == GetWinningPlayer())
        SetHighlight( player )

	thread OnPlayerRespawned_Threaded( player )
}

void function OnPlayerRespawned_Threaded( entity player )
{
	// bit of a hack, need to rework earnmeter code to have better support for completely disabling it
	// rn though this just waits for earnmeter code to set the mode before we set it back
	WaitFrame()
	if ( IsValid( player ) )
		PlayerEarnMeter_SetMode( player, eEarnMeterMode.DISABLED )
}

entity function GetWinningPlayer() 
{
    entity bestplayer

    foreach ( entity player in GetPlayerArray() ) {
        if (bestplayer == null)
            bestplayer = player
        
        if (GameRules_GetTeamScore(player.GetTeam()) > GameRules_GetTeamScore(bestplayer.GetTeam()))
            bestplayer = player
    }

    return bestplayer
}

void function SetHighlight(entity player) {
    foreach ( entity player in GetPlayerArray() )
        Highlight_ClearEnemyHighlight(player)
    Highlight_SetEnemyHighlight( player, file.score_leader_highlight )
}