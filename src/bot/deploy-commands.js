const { REST, Routes } = require('discord.js');
require('dotenv').config();
const config = require('../config');
const commands = require('./commands');

const rest = new REST({ version: '10' }).setToken(config.discord.token);

(async () => {
  try {
    console.log(`🔄  Registering ${commands.length} slash command(s)…`);

    await rest.put(
      Routes.applicationGuildCommands(
        config.discord.clientId,
        config.discord.guildId,
      ),
      { body: commands },
    );

    console.log('✅  Slash commands registered successfully.');
  } catch (error) {
    console.error('❌  Failed to register slash commands:', error);
    process.exit(1);
  }
})();
