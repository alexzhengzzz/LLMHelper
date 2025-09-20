import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { UserProfile, UserProfileData } from '../utils/AppStorage';
import { UserProfileManager } from '../utils/UserProfileManager';
import { Logger } from '../utils/Logger';

interface AvatarOption {
  text: string;
  value: string;
}

/**
 * 用户资料编辑页面
 */
@Entry
@ComponentV2
struct UserProfileEditPage {
  @Local userName: string = '';
  @Local userSignature: string = '';
  @Local userAvatarType: 'default' | 'emoji' | 'image' = 'default';
  @Local userAvatarValue: string = '#4285F4';
  @Local statusBarHeight: number = 44;
  @Local hasChanges: boolean = false; // 是否有未保存的更改
  @Local isSaving: boolean = false; // 是否正在保存
  @Local validationErrors: string[] = []; // 验证错误信息
  @Local screenWidth: number = 0; // 屏幕宽度
  @Local isCompactScreen: boolean = false; // 是否为紧凑屏幕
  
  // 设计系统 - 间距tokens (基于8px网格)
  private readonly SPACING_XS: number = 4;    // 超小间距
  private readonly SPACING_SM: number = 8;    // 小间距
  private readonly SPACING_MD: number = 12;   // 中等间距
  private readonly SPACING_LG: number = 16;   // 大间距
  private readonly SPACING_XL: number = 20;   // 超大间距
  private readonly SPACING_XXL: number = 24;  // 巨大间距
  private readonly SPACING_XXXL: number = 32; // 最大间距
  
  // 组件尺寸tokens
  private readonly SIZE_AVATAR: number = 72;        // 头像尺寸
  private readonly SIZE_INPUT_HEIGHT: number = 44;   // 输入框高度
  private readonly SIZE_TEXTAREA_HEIGHT: number = 72; // 多行文本输入框高度
  private readonly SIZE_BUTTON_HEIGHT: number = 44;  // 按钮高度
  private readonly SIZE_NAV_HEIGHT: number = 48;     // 导航栏高度
  
  // 边框圆角tokens
  private readonly RADIUS_SM: number = 6;   // 小圆角
  private readonly RADIUS_MD: number = 8;   // 中等圆角
  private readonly RADIUS_LG: number = 12;  // 大圆角
  private readonly RADIUS_XL: number = 16;  // 超大圆角
  
  private userProfileManager: UserProfileManager = UserProfileManager.getInstance();
  private originalProfile: UserProfile | null = null; // 原始资料，用于比较是否有更改

  async aboutToAppear(): Promise<void> {
    Logger.info('UserProfileEditPage', 'aboutToAppear');
    
    try {
      // 初始化用户资料管理器
      await this.userProfileManager.initialize();
      
      // 加载当前用户资料
      const currentProfile = this.userProfileManager.getCurrentProfile();
      if (currentProfile) {
        this.originalProfile = currentProfile.clone();
        this.userName = currentProfile.userName;
        this.userSignature = currentProfile.userSignature;
        this.userAvatarType = currentProfile.userAvatarType;
        this.userAvatarValue = currentProfile.userAvatarValue;
        Logger.info('UserProfileEditPage', `加载用户资料: ${this.userName}`);
      }
      
      // 初始化响应式设计
      this.initResponsiveDesign();
    } catch (error) {
      Logger.error('UserProfileEditPage', `初始化失败: ${error}`);
    }
  }
  
  /**
   * 初始化响应式设计
   */
  private initResponsiveDesign(): void {
    // 这里可以根据实际需要设置屏幕宽度检测
    // 目前使用默认值，在实际应用中可以通过系统 API 获取
    this.screenWidth = 360; // 默认宽度
    this.isCompactScreen = this.screenWidth < 400;
  }
  
  /**
   * 获取响应式间距
   */
  private getResponsiveSpacing(baseSpacing: number): number {
    return this.isCompactScreen ? Math.max(baseSpacing - 4, 4) : baseSpacing;
  }
  
  /**
   * 获取响应式尺寸
   */
  private getResponsiveSize(baseSize: number): number {
    return this.isCompactScreen ? Math.max(baseSize - 8, baseSize * 0.8) : baseSize;
  }
  
  /**
   * 获取间距值
   */
  private getSpacing(type: 'xs' | 'sm' | 'md' | 'lg' | 'xl' | 'xxl' | 'xxxl'): number {
    switch (type) {
      case 'xs': return this.SPACING_XS;
      case 'sm': return this.SPACING_SM;
      case 'md': return this.SPACING_MD;
      case 'lg': return this.SPACING_LG;
      case 'xl': return this.SPACING_XL;
      case 'xxl': return this.SPACING_XXL;
      case 'xxxl': return this.SPACING_XXXL;
      default: return this.SPACING_MD;
    }
  }
  
  /**
   * 获取尺寸值
   */
  private getSize(type: 'avatar' | 'inputHeight' | 'textAreaHeight' | 'buttonHeight' | 'navHeight'): number {
    switch (type) {
      case 'avatar': return this.SIZE_AVATAR;
      case 'inputHeight': return this.SIZE_INPUT_HEIGHT;
      case 'textAreaHeight': return this.SIZE_TEXTAREA_HEIGHT;
      case 'buttonHeight': return this.SIZE_BUTTON_HEIGHT;
      case 'navHeight': return this.SIZE_NAV_HEIGHT;
      default: return this.SIZE_INPUT_HEIGHT;
    }
  }
  
  /**
   * 获取圆角值
   */
  private getRadius(type: 'sm' | 'md' | 'lg' | 'xl'): number {
    switch (type) {
      case 'sm': return this.RADIUS_SM;
      case 'md': return this.RADIUS_MD;
      case 'lg': return this.RADIUS_LG;
      case 'xl': return this.RADIUS_XL;
      default: return this.RADIUS_MD;
    }
  }

  onBackPress(): boolean | void {
    if (this.hasChanges) {
      this.showUnsavedChangesDialog();
      return true; // 阻止默认返回行为
    }
    return false; // 允许正常返回
  }

  /**
   * 检查是否有未保存的更改
   */
  private checkForChanges(): void {
    if (!this.originalProfile) {
      this.hasChanges = false;
      return;
    }

    this.hasChanges = (
      this.userName !== this.originalProfile.userName ||
      this.userSignature !== this.originalProfile.userSignature ||
      this.userAvatarType !== this.originalProfile.userAvatarType ||
      this.userAvatarValue !== this.originalProfile.userAvatarValue
    );
  }

  /**
   * 验证输入
   */
  private validateInput(): void {
    const validation = this.userProfileManager.validateProfileInput(this.userName, this.userSignature);
    this.validationErrors = validation.errors;
  }

  /**
   * 保存用户资料
   */
  private async saveProfile(): Promise<void> {
    if (this.isSaving) return;

    try {
      this.isSaving = true;
      this.validateInput();

      if (this.validationErrors.length > 0) {
        Logger.warn('UserProfileEditPage', `输入验证失败: ${this.validationErrors.join(', ')}`);
        return;
      }

      const updates: Partial<UserProfileData> = {
        userName: this.userName,
        userSignature: this.userSignature,
        userAvatarType: this.userAvatarType,
        userAvatarValue: this.userAvatarValue
      };

      const success = await this.userProfileManager.updateProfile(updates);
      
      if (success) {
        Logger.info('UserProfileEditPage', '用户资料保存成功');
        this.hasChanges = false;
        
        // 显示保存成功提示
        AlertDialog.show({
          title: '保存成功',
          message: '个人资料已更新',
          confirm: {
            value: '确定',
            action: () => {
              router.back();
            }
          }
        });
      } else {
        Logger.error('UserProfileEditPage', '用户资料保存失败');
        AlertDialog.show({
          title: '保存失败',
          message: '更新个人资料时发生错误，请重试',
          confirm: {
            value: '确定',
            action: () => {}
          }
        });
      }
    } catch (error) {
      Logger.error('UserProfileEditPage', `保存用户资料异常: ${error}`);
    } finally {
      this.isSaving = false;
    }
  }

  /**
   * 显示未保存更改对话框
   */
  private showUnsavedChangesDialog(): void {
    AlertDialog.show({
      title: '未保存的更改',
      message: '您有未保存的更改，是否要保存后离开？',
      primaryButton: {
        value: '不保存',
        fontColor: $r('app.color.text_secondary'),
        action: () => {
          router.back();
        }
      },
      secondaryButton: {
        value: '保存',
        fontColor: $r('app.color.primary_color'),
        action: async () => {
          await this.saveProfile();
        }
      }
    });
  }

  build() {
    Column() {
      // 顶部导航栏
      Column() {
        this.buildNavigationBar()
      }
      .margin({ top: this.statusBarHeight })

      // 内容区域
      Scroll() {
        Column() {
          // 头像编辑区域
          this.buildAvatarSection()

          // 基本信息编辑区域
          this.buildBasicInfoSection()

          // 验证错误提示
          if (this.validationErrors.length > 0) {
            this.buildValidationErrors()
          }

          // 保存按钮
          this.buildSaveButton()
        }
        .width('100%')
        .padding({ 
          left: this.getResponsiveSpacing(this.getSpacing('lg')), 
          right: this.getResponsiveSpacing(this.getSpacing('lg')), 
          top: this.getResponsiveSpacing(this.getSpacing('lg')), 
          bottom: this.getResponsiveSpacing(this.getSpacing('xxxl')) 
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_color'))
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Button('取消')
        .fontSize(15)
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.primary_color'))
        .onClick(() => {
          if (this.hasChanges) {
            this.showUnsavedChangesDialog();
          } else {
            router.back();
          }
        })

      Text('编辑个人资料')
        .fontSize(17)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Button('完成')
        .fontSize(15)
        .backgroundColor(Color.Transparent)
        .fontColor(this.hasChanges && this.validationErrors.length === 0 ? $r('app.color.primary_color') : $r('app.color.text_secondary'))
        .enabled(this.hasChanges && this.validationErrors.length === 0 && !this.isSaving)
        .onClick(async () => {
          await this.saveProfile();
        })
    }
    .width('100%')
    .height(this.getSize('navHeight'))
    .padding({ left: this.getSpacing('lg'), right: this.getSpacing('lg') })
    .backgroundColor($r('app.color.surface_color'))
    .shadow({
      radius: 2,
      color: '#0D000000',
      offsetY: 1
    })
  }

  @Builder
  buildAvatarSection() {
    Column() {
      Text('头像')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: this.getSpacing('md') })

      // 头像预览和编辑
      Column() {
        // 头像显示
        Column() {
          this.buildAvatarPreview()
        }
        .margin({ bottom: this.getSpacing('md') })

        // 更换头像按钮
        Button('更换头像')
          .type(ButtonType.Normal)
          .fontSize(15)
          .fontColor($r('app.color.primary_color'))
          .backgroundColor($r('app.color.input_background'))
          .width(100)
          .height(this.getSize('buttonHeight') - 8)
          .borderRadius(this.getRadius('md'))
          .onClick(() => {
            this.showAvatarSelectionDialog();
          })
      }
      .width('100%')
      .padding({ 
        top: this.getSpacing('lg'), 
        bottom: this.getSpacing('lg'),
        left: this.getSpacing('lg'),
        right: this.getSpacing('lg')
      })
      .backgroundColor($r('app.color.surface_color'))
      .borderRadius(this.getRadius('lg'))
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: this.getSpacing('lg') })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildAvatarPreview() {
    if (this.userAvatarType === 'emoji') {
      Text(this.userAvatarValue)
        .fontSize(40)
        .width(this.getResponsiveSize(this.getSize('avatar')))
        .height(this.getResponsiveSize(this.getSize('avatar')))
        .textAlign(TextAlign.Center)
        .border({ 
          width: 2, 
          color: $r('app.color.border_color'), 
          radius: this.getSize('avatar') / 2 
        })
        .backgroundColor($r('app.color.surface_color'))
    } else if (this.userAvatarType === 'image') {
      Image(this.userAvatarValue)
        .width(this.getResponsiveSize(this.getSize('avatar')))
        .height(this.getResponsiveSize(this.getSize('avatar')))
        .borderRadius(this.getSize('avatar') / 2)
        .border({ width: 2, color: $r('app.color.border_color') })
        .objectFit(ImageFit.Cover)
        .onError(() => {
          Logger.warn('UserProfileEditPage', '头像图片加载失败');
        })
    } else {
      Circle({ width: this.getSize('avatar'), height: this.getSize('avatar') })
        .fill(this.userAvatarValue)
        .border({ width: 2, color: $r('app.color.border_color') })
    }
  }

  @Builder
  buildBasicInfoSection() {
    Column() {
      // 用户名编辑
      Column() {
        Text('用户名')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ bottom: this.getSpacing('sm') })

        TextInput({ text: this.userName, placeholder: '请输入用户名（1-20字符）' })
          .width('100%')
          .height(this.getSize('inputHeight'))
          .fontSize(16)
          .backgroundColor($r('app.color.input_background'))
          .borderRadius(this.getRadius('md'))
          .padding({ left: this.getSpacing('lg'), right: this.getSpacing('lg') })
          .onChange((value: string) => {
            this.userName = value;
            this.checkForChanges();
            this.validateInput();
          })
          .maxLength(20)

        // 字符计数
        Text(`${this.userName.length}/20`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.End)
          .margin({ top: this.getSpacing('xs') })
      }
      .width('100%')
      .margin({ bottom: this.getSpacing('lg') })

      // 个性签名编辑
      Column() {
        Text('个性签名')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ bottom: this.getSpacing('sm') })

        TextArea({ text: this.userSignature, placeholder: '写点什么介绍自己吧（最多50字符）' })
          .width('100%')
          .height(this.getSize('textAreaHeight'))
          .fontSize(16)
          .backgroundColor($r('app.color.input_background'))
          .borderRadius(this.getRadius('md'))
          .padding({ 
            left: this.getSpacing('lg'), 
            right: this.getSpacing('lg'), 
            top: this.getSpacing('md'), 
            bottom: this.getSpacing('md') 
          })
          .onChange((value: string) => {
            this.userSignature = value;
            this.checkForChanges();
            this.validateInput();
          })
          .maxLength(50)

        // 字符计数
        Text(`${this.userSignature.length}/50`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.End)
          .margin({ top: this.getSpacing('xs') })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ 
      top: this.getSpacing('lg'), 
      bottom: this.getSpacing('lg'), 
      left: this.getSpacing('lg'), 
      right: this.getSpacing('lg') 
    })
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(this.getRadius('lg'))
    .margin({ bottom: this.getSpacing('lg') })
  }

  @Builder
  buildValidationErrors() {
    Column() {
      Row() {
        Text('⚠️')
          .fontSize(16)
          .margin({ right: this.getSpacing('sm') })
        
        Column() {
          ForEach(this.validationErrors, (error: string, index: number) => {
            Text(error)
              .fontSize(14)
              .fontColor('#D32F2F')
              .width('100%')
              .margin({ bottom: index < this.validationErrors.length - 1 ? this.getSpacing('xs') : 0 })
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding({ 
      left: this.getResponsiveSpacing(this.getSpacing('lg')), 
      right: this.getResponsiveSpacing(this.getSpacing('lg')), 
      top: this.getResponsiveSpacing(this.getSpacing('md')), 
      bottom: this.getResponsiveSpacing(this.getSpacing('md')) 
    })
    .backgroundColor('#FFEBEE')
    .borderRadius(this.getRadius('md'))
    .border({ width: 1, color: '#FFCDD2' })
    .margin({ bottom: this.getResponsiveSpacing(this.getSpacing('lg')) })
  }

  @Builder
  buildSaveButton() {
    Button(this.isSaving ? '保存中...' : '保存更改')
      .type(ButtonType.Normal)
      .fontSize(16)
      .fontColor('#FFFFFF')
      .backgroundColor(this.hasChanges && this.validationErrors.length === 0 ? $r('app.color.primary_color') : $r('app.color.text_secondary'))
      .width('100%')
      .height(this.getSize('buttonHeight'))
      .borderRadius(this.getRadius('md'))
      .enabled(this.hasChanges && this.validationErrors.length === 0 && !this.isSaving)
      .margin({ top: this.getSpacing('lg') })
      .onClick(async () => {
        await this.saveProfile();
      })
  }

  /**
   * 显示头像选择对话框
   */
  private showAvatarSelectionDialog(): void {
    const avatarOptions: AvatarOption[] = [
      { text: '默认蓝色', value: 'default:#4285F4' },
      { text: '默认绿色', value: 'default:#34A853' },
      { text: '默认红色', value: 'default:#EA4335' },
      { text: '默认橙色', value: 'default:#FBBC05' },
      { text: '默认紫色', value: 'default:#9C27B0' },
      { text: '😀', value: 'emoji:😀' },
      { text: '🙂', value: 'emoji:🙂' },
      { text: '😊', value: 'emoji:😊' },
      { text: '🤔', value: 'emoji:🤔' },
      { text: '🤖', value: 'emoji:🤖' },
      { text: '👨‍💻', value: 'emoji:👨‍💻' },
      { text: '👩‍💻', value: 'emoji:👩‍💻' },
      { text: '选择图片', value: 'image:select' }
    ];

    this.showAvatarGridDialog(avatarOptions);
  }

  /**
   * 显示头像网格选择对话框
   */
  private showAvatarGridDialog(options: AvatarOption[]): void {
    const optionTexts = options.map((opt: AvatarOption) => opt.text);
    
    TextPickerDialog.show({
      range: optionTexts,
      selected: 0,
      onAccept: async (value: TextPickerResult) => {
        const selectedIndex: number = value.index as number;
        const selectedOption = options[selectedIndex];
        
        if (selectedOption.value === 'image:select') {
          await this.selectImageFromGallery();
        } else {
          const parts = selectedOption.value.split(':');
          const type = parts[0] as 'default' | 'emoji';
          const val = parts[1];
          this.updateAvatarSetting(type, val);
        }
      },
      onCancel: () => {
        // 取消头像选择
      }
    });
  }

  /**
   * 从相册选择图片
   */
  private async selectImageFromGallery(): Promise<void> {
    try {
      const photoSelectOptions: picker.PhotoSelectOptions = {
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };

      const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
      const photoSelectResult: picker.PhotoSelectResult = await photoPicker.select(photoSelectOptions);

      if (photoSelectResult.photoUris.length > 0) {
        const imageUri: string = photoSelectResult.photoUris[0];
        this.updateAvatarSetting('image', imageUri);
        Logger.info('UserProfileEditPage', '头像图片选择成功');
      }
    } catch (error) {
      Logger.error('UserProfileEditPage', `选择头像图片失败: ${error}`);
      AlertDialog.show({
        title: '选择失败',
        message: '无法选择图片，请重试',
        confirm: {
          value: '确定',
          action: () => {}
        }
      });
    }
  }

  /**
   * 更新头像设置
   */
  private updateAvatarSetting(type: 'default' | 'emoji' | 'image', value: string): void {
    this.userAvatarType = type;
    this.userAvatarValue = value;
    this.checkForChanges();
    Logger.info('UserProfileEditPage', `头像已更新: ${type} = ${value}`);
  }
}