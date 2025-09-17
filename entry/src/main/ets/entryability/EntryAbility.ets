import { abilityAccessCtrl, AbilityConstant, UIAbility, Want, ConfigurationConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppContext } from '../utils/AppContext';
import { BusinessError } from '@kit.BasicServicesKit';
import { Configuration } from '@kit.AbilityKit';
import { ThemeManager } from '../utils/ThemeManager';
import { AppConfigManager } from '../utils/AppConfigManager';

export default class EntryAbility extends UIAbility {
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private appConfigManager: AppConfigManager = AppConfigManager.getInstance();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    
    // 设置应用上下文
    AppContext.getInstance().setContext(this.context);
    
    // 初始化应用配置管理器
    this.appConfigManager.initialize().then(() => {
      hilog.info(0x0000, 'testTag', 'AppConfigManager initialized successfully');
    }).catch((error: Error) => {
      hilog.error(0x0000, 'testTag', `Failed to initialize AppConfigManager: ${error.message}`);
    });
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(this.context, ['ohos.permission.MICROPHONE']).then((data) => {
      hilog.info(0x0000, 'testTag', 'data:' + JSON.stringify(data));
      hilog.info(0x0000, 'testTag', 'data permissions:' + data.permissions);
      hilog.info(0x0000, 'testTag', 'data authResults:' + data.authResults);
    }).catch((err: BusinessError) => {
      hilog.error(0x0000, 'testTag', 'errCode: ' + err.code + 'errMessage: ' + err.message);
    });
    windowStage.loadContent('pages/ChatPage', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      this.setupImmersiveMode(windowStage).then(() => {
        hilog.info(0x0000, 'testTag', 'Immersive mode setup completed');
      }).catch((err: BusinessError) => {
        hilog.error(0x0000, 'testTag', `Failed to setup immersive mode: ${err.code} - ${err.message}`);
      });
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }

  onConfigurationUpdate(config: Configuration): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onConfigurationUpdate');
    
    // 检查系统主题变化
    const isSystemDark = config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    hilog.info(0x0000, 'testTag', `System theme changed to: ${isSystemDark ? 'dark' : 'light'}`);
    
    // 异步更新主题
    this.themeManager.updateDarkMode(isSystemDark).catch((error: Error) => {
      hilog.error(0x0000, 'testTag', `Failed to update theme from system: ${error.message}`);
    });
  }

  /**
   * 设置沉浸式模式 - 隐藏状态栏
   */
  private async setupImmersiveMode(windowStage: window.WindowStage): Promise<void> {
    try {
      hilog.info(0x0000, 'testTag', 'Setting up immersive mode with hidden status bar');
      
      // 获取主窗口
      const windowClass = await windowStage.getMainWindow();
      
      // 设置全屏布局，让页面内容延伸到状态栏下方
      await windowClass.setWindowLayoutFullScreen(true);
      
      // 隐藏系统状态栏，保留导航栏
      await windowClass.setWindowSystemBarEnable(['navigation']);
      
      // 设置状态栏为完全透明背景
      await windowClass.setWindowSystemBarProperties({
        statusBarColor: '#00000000', // 完全透明状态栏背景
        navigationBarColor: '#00000000', // 完全透明导航栏背景
        statusBarContentColor: '#FFFFFFFF', // 状态栏内容颜色（白色）
        navigationBarContentColor: '#FFFFFFFF', // 导航栏内容颜色（白色）
        isStatusBarLightIcon: false // 状态栏图标为深色模式
      });
      
      // 获取状态栏区域高度并存储到AppStorage
      const statusArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const statusBarHeight = px2vp(statusArea.topRect.height);
      AppStorage.setOrCreate('statusBarHeight', statusBarHeight);
      hilog.info(0x0000, 'testTag', `Status bar height: ${statusBarHeight}vp`);
      
      // 获取导航栏高度并存储
      const navArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const navBarHeight = px2vp(navArea.bottomRect.height);
      AppStorage.setOrCreate('navBarHeight', navBarHeight);
      hilog.info(0x0000, 'testTag', `Navigation bar height: ${navBarHeight}vp`);
      
      // 注册监听函数，动态获取避让区域变化
      windowClass.on('avoidAreaChange', (data) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          const newStatusBarHeight = px2vp(data.area.topRect.height);
          AppStorage.setOrCreate('statusBarHeight', newStatusBarHeight);
          hilog.info(0x0000, 'testTag', `Status bar height changed: ${newStatusBarHeight}vp`);
        } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          const newNavBarHeight = px2vp(data.area.bottomRect.height);
          AppStorage.setOrCreate('navBarHeight', newNavBarHeight);
          hilog.info(0x0000, 'testTag', `Navigation bar height changed: ${newNavBarHeight}vp`);
        }
      });
      
      hilog.info(0x0000, 'testTag', 'Hidden status bar immersive mode setup completed');
    } catch (error) {
      hilog.error(0x0000, 'testTag', `Failed to setup immersive mode: ${error}`);
    }
  }
}