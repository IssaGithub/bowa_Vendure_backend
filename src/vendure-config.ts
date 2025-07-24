import {
    dummyPaymentHandler,
    DefaultJobQueuePlugin,
    DefaultSchedulerPlugin,
    DefaultSearchPlugin,
    VendureConfig,
} from '@vendure/core';
import { defaultEmailHandlers, EmailPlugin, FileBasedTemplateLoader } from '@vendure/email-plugin';
import { AssetServerPlugin } from '@vendure/asset-server-plugin';
import { AdminUiPlugin } from '@vendure/admin-ui-plugin';
import { GraphiqlPlugin } from '@vendure/graphiql-plugin';
import 'dotenv/config';
import path from 'path';

const IS_DEV = process.env.APP_ENV === 'dev';
const serverPort = +process.env.PORT || 3000;

// Database configuration based on environment
const getDatabaseConfig = () => {
    const databaseType = process.env.DATABASE_TYPE || 'better-sqlite3';
    
    if (databaseType === 'postgres') {
        return {
            type: 'postgres' as const,
            host: process.env.DATABASE_HOST || 'localhost',
            port: +process.env.DATABASE_PORT || 5432,
            username: process.env.DATABASE_USERNAME || 'postgres',
            password: process.env.DATABASE_PASSWORD || '',
            database: process.env.DATABASE_NAME || 'vendure',
            synchronize: false,
            migrations: [path.join(__dirname, './migrations/*.+(js|ts)')],
            logging: IS_DEV,
            ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
        };
    } else {
        // Default to SQLite for development
        return {
            type: 'better-sqlite3' as const,
            synchronize: false,
            migrations: [path.join(__dirname, './migrations/*.+(js|ts)')],
            logging: false,
            database: path.join(__dirname, '../vendure.sqlite'),
        };
    }
};

export const config: VendureConfig = {
    apiOptions: {
        port: serverPort,
        adminApiPath: 'admin-api',
        shopApiPath: 'shop-api',
        // The following options are useful in development mode,
        // but are best turned off for production for security
        // reasons.
        ...(IS_DEV ? {
            adminApiDebug: true,
            shopApiDebug: true,
        } : {}),
    },
    authOptions: {
        tokenMethod: ['bearer', 'cookie'],
        superadminCredentials: {
            identifier: process.env.SUPERADMIN_USERNAME || 'superadmin',
            password: process.env.SUPERADMIN_PASSWORD || 'superadmin',
        },
        cookieOptions: {
          secret: process.env.COOKIE_SECRET || 'cookie-secret',
        },
    },
    dbConnectionOptions: getDatabaseConfig(),
    paymentOptions: {
        paymentMethodHandlers: [dummyPaymentHandler],
    },
    // When adding or altering custom field definitions, the database will
    // need to be updated. See the "Migrations" section in README.md.
    customFields: {},
    plugins: [
        GraphiqlPlugin.init(),
        AssetServerPlugin.init({
            route: 'assets',
            assetUploadDir: path.join(__dirname, '../static/assets'),
            // For local dev, the correct value for assetUrlPrefix should
            // be guessed correctly, but for production it will usually need
            // to be set manually to match your production url.
            assetUrlPrefix: IS_DEV ? undefined : process.env.ASSET_URL_PREFIX || 'https://api.yourdomain.com/assets/',
        }),
        DefaultSchedulerPlugin.init(),
        DefaultJobQueuePlugin.init({ useDatabaseForBuffer: true }),
        DefaultSearchPlugin.init({ bufferUpdates: false, indexStockStatus: true }),
        EmailPlugin.init({
            devMode: IS_DEV,
            outputPath: path.join(__dirname, '../static/email/test-emails'),
            route: 'mailbox',
            handlers: defaultEmailHandlers,
            templateLoader: new FileBasedTemplateLoader(path.join(__dirname, '../static/email/templates')),
            globalTemplateVars: {
                // The following variables will change depending on your storefront implementation.
                // Here we are assuming a storefront running at http://localhost:8080.
                fromAddress: IS_DEV ? '"example" <noreply@example.com>' : process.env.EMAIL_FROM_ADDRESS || '"Bowa Shop" <noreply@yourdomain.com>',
                verifyEmailAddressUrl: IS_DEV ? 'http://localhost:8080/verify' : process.env.EMAIL_VERIFY_URL || 'https://yourdomain.com/verify',
                passwordResetUrl: IS_DEV ? 'http://localhost:8080/password-reset' : process.env.EMAIL_PASSWORD_RESET_URL || 'https://yourdomain.com/password-reset',
                changeEmailAddressUrl: IS_DEV ? 'http://localhost:8080/verify-email-address-change' : process.env.EMAIL_CHANGE_EMAIL_URL || 'https://yourdomain.com/verify-email-address-change'
            },
        }),
        AdminUiPlugin.init({
            route: 'admin',
            port: IS_DEV ? serverPort + 2 : serverPort,
            adminUiConfig: {
                apiPort: serverPort,
            },
        }),
    ],
};

