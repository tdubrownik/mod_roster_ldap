# Prosody shared roster from LDAP

This is a toy shared roster written for Hackerspace Warsaw.
It pulls all users matching a specific filter using LDAP and automatically adds them to every user's roster.

Very basic functionality, more updates hopefully coming soon.

## Configuration

LDAP settings are the same as the ones used by https://modules.prosody.im/mod_auth_ldap.html

This modules accepts the following additionnal settings:
* ldap_uidattr: Sets the attribute that sets the user part of the JID (default: uid)
* ldap_nameattr: Sets the attribute that sets the user name (displayed in the roster afterwards) (default: cn)
* group_name: Sets the shared roster name (default: 'Shared roster')
* refresh_time: Refresh the shared roster every X seconds (default: 60)

Example:
```lua
ldap_roster = {
	ldap_uidattr  = 'uid';
	ldap_nameattr = 'cn';
	group_name    = 'Shared roster';
	refresh_time  = 60;
};
```
