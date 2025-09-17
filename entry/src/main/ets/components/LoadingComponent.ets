import { curves } from '@kit.ArkUI';

/**
 * 自定义Loading动画组件
 * 集成Javis动画系统，高端精致简单易用
 */
@ComponentV2
export struct LoadingComponent {
  @Param componentSize: number = 40;
  @Param color: ResourceColor = $r('app.color.primary_color');
  @Param type: 'pulse' | 'rotate' | 'bounce' | 'dots' = 'pulse';
  @Param text: string = '';
  @Local animationAngle: number = 0;
  @Local animationScale: number = 1;
  @Local animationOpacity: number = 1;

  aboutToAppear(): void {
    // 初始化动画系统
    SimpleAnimationManager.getInstance().initialize();
    this.startAnimation();
  }

  build() {
    Column() {
      // 动画主体
      if (this.type === 'pulse') {
        this.buildPulseAnimation()
      } else if (this.type === 'rotate') {
        this.buildRotateAnimation()
      } else if (this.type === 'bounce') {
        this.buildBounceAnimation()
      } else if (this.type === 'dots') {
        this.buildDotsAnimation()
      }
      
      // 加载文本
      if (this.text) {
        Text(this.text)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 12 })
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildPulseAnimation() {
    Stack() {
      // 外圈脉冲 - 使用新动画系统
      Circle({ width: this.componentSize, height: this.componentSize })
        .fill(this.color)
        .opacity(0.3)
        .scale({ x: this.animationScale * 1.2, y: this.animationScale * 1.2 })
        .animation({
          duration: 1500,
          curve: curves.springMotion(0.7, 0.8),
          iterations: -1,
          playMode: PlayMode.Alternate
        })
      
      // 内圈核心 - 增强弹性效果
      Circle({ width: this.componentSize * 0.6, height: this.componentSize * 0.6 })
        .fill(this.color)
        .scale({ x: this.animationScale, y: this.animationScale })
        .animation(SimpleAnimationPresets.STANDARD)
      
      // 增加能量环效果
      Circle({ width: this.componentSize * 1.4, height: this.componentSize * 1.4 })
        .fill(Color.Transparent)
        .border({ width: 1, color: this.color })
        .opacity(0.2)
        .scale({ x: this.animationScale * 0.8, y: this.animationScale * 0.8 })
        .animation({
          duration: 800,
          curve: curves.springMotion(0.85, 0.8),
          iterations: -1,
          playMode: PlayMode.Alternate
        })
    }
    .width(this.componentSize)
    .height(this.componentSize)
  }

  @Builder
  buildRotateAnimation() {
    Stack() {
      // 旋转外圈
      Circle({ width: this.componentSize, height: this.componentSize })
        .fill(Color.Transparent)
        .stroke(this.color)
        .strokeWidth(3)
        .strokeDashArray([5, 5])
        .rotate({ 
          angle: this.animationAngle, 
          centerX: '50%', 
          centerY: '50%' 
        })
        .animation({
          duration: 300,
          curve: curves.springMotion(0.7, 0.8),
          iterations: -1,
          playMode: PlayMode.Normal
        })
      
      // 中心点
      Circle({ width: this.componentSize * 0.3, height: this.componentSize * 0.3 })
        .fill(this.color)
    }
    .width(this.componentSize)
    .height(this.componentSize)
  }

  @Builder
  buildBounceAnimation() {
    Column() {
      // 弹跳球
      Circle({ width: this.componentSize * 0.8, height: this.componentSize * 0.8 })
        .fill(this.color)
        .translate({ y: this.animationScale * 10 })
        .animation({
          duration: 300,
          curve: curves.springMotion(0.7, 0.8),
          iterations: -1,
          playMode: PlayMode.Alternate
        })
    }
    .width(this.componentSize)
    .height(this.componentSize)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildDotsAnimation() {
    Row() {
      // 三个跳动的点
      ForEach([0, 1, 2], (index: number) => {
        Circle({ width: this.componentSize * 0.2, height: this.componentSize * 0.2 })
          .fill(this.color)
          .opacity(this.animationOpacity)
          .scale({ x: this.animationScale, y: this.animationScale })
          .animation({
            duration: 300,
            curve: curves.springMotion(0.7, 0.8),
            delay: index * 100,
            iterations: -1,
            playMode: PlayMode.Alternate
          })
          .margin({ left: index > 0 ? this.componentSize * 0.1 : 0 })
      })
    }
    .width(this.componentSize)
    .height(this.componentSize * 0.2)
    .justifyContent(FlexAlign.Center)
  }

  private startAnimation(): void {
    // 使用定时器更新动画状态
    setInterval(() => {
      this.animationScale = this.animationScale === 1 ? 1.2 : 1;
      this.animationOpacity = this.animationOpacity === 1 ? 0.6 : 1;
      this.animationAngle = (this.animationAngle + 45) % 360;
    }, 200);
  }
}