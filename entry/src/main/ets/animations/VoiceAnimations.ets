import { AnimationManager, AnimationType } from './AnimationManager';
import { Logger } from '../utils/Logger';
import { curves } from '@kit.ArkUI';

/**
 * 语音状态枚举
 */
export enum VoiceAnimationState {
  IDLE = 'idle',
  LISTENING = 'listening',
  PROCESSING = 'processing',
  SPEAKING = 'speaking',
  ERROR = 'error'
}

/**
 * 波形数据接口
 */
export interface WaveformData {
  amplitudes: number[];
  frequency: number;
  maxAmplitude: number;
}

/**
 * 语音交互动画类
 */
export class VoiceAnimations {
  private static animationManager = AnimationManager.getInstance();

  /**
   * 语音录音呼吸动画
   */
  static breathingAnimation() {
    const config = this.animationManager.getAnimationConfig(AnimationType.VOICE_RECORDING);
    
    return {
      scale: { x: 1.2, y: 1.2 },
      opacity: 0.8,
      animation: {
        duration: config.duration,
        curve: config.curve,
        iterations: -1,
        playMode: PlayMode.Alternate
      }
    };
  }

  /**
   * 语音波形动画
   */
  static waveformAnimation(amplitude: number = 0.5) {
    const normalizedAmplitude = Math.max(0.1, Math.min(1.0, amplitude));
    
    return {
      scale: { x: 1 + normalizedAmplitude * 0.5, y: 1 + normalizedAmplitude * 0.3 },
      animation: {
        duration: 100,
        curve: Curve.Linear
      }
    };
  }

  /**
   * 麦克风脉冲动画
   */
  static microphonePulseAnimation() {
    return {
      scale: { x: 1.1, y: 1.1 },
      opacity: 0.7,
      animation: {
        curve: curves.springMotion(0.5, 0.75),
        iterations: -1,
        playMode: PlayMode.Alternate
      }
    };
  }

  /**
   * 语音处理旋转动画
   */
  static processingSpinAnimation() {
    const config = this.animationManager.getAnimationConfig(AnimationType.VOICE_PROCESSING);
    
    return {
      rotate: { angle: 360 },
      animation: {
        duration: 1000,
        curve: Curve.Linear,
        iterations: -1
      }
    };
  }

  /**
   * 语音识别成功动画
   */
  static recognitionSuccessAnimation() {
    return {
      scale: { x: 1.3, y: 1.3 },
      opacity: 0.9,
      animation: {
        curve: curves.springMotion(0.8, 0.75),
        playMode: PlayMode.Alternate,
        iterations: 2
      }
    };
  }

  /**
   * 语音识别错误动画
   */
  static recognitionErrorAnimation() {
    return {
      translate: { x: 5, y: 0 },
      animation: {
        duration: 100,
        curve: Curve.Sharp,
        playMode: PlayMode.Alternate,
        iterations: 6
      }
    };
  }

  /**
   * TTS播放指示动画
   */
  static ttsPlayingAnimation() {
    return {
      scale: { x: 1.1, y: 1.1 },
      opacity: 0.8,
      animation: {
        duration: 500,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate
      }
    };
  }

  /**
   * 音频波形条动画
   */
  static audioBarAnimation(index: number, amplitude: number) {
    const delay = index * 50;
    const height = Math.max(0.2, amplitude);
    
    return {
      scale: { x: 1, y: height },
      animation: {
        duration: 150,
        curve: Curve.EaseOut,
        delay: delay
      }
    };
  }

  /**
   * 环形音频可视化动画
   */
  static circularAudioVisualization(data: WaveformData) {
    const animations = [];
    const stepAngle = 360 / data.amplitudes.length;
    
    data.amplitudes.forEach((amplitude, index) => {
      const angle = index * stepAngle;
      const normalizedAmplitude = amplitude / data.maxAmplitude;
      const scale = 0.3 + normalizedAmplitude * 0.7;
      
      animations.push({
        rotate: { angle },
        scale: { x: scale, y: scale },
        animation: {
          duration: 100,
          curve: Curve.EaseOut
        }
      });
    });
    
    return animations;
  }

  /**
   * 语音气泡动画
   */
  static voiceBubbleAnimation() {
    return {
      scale: { x: 0, y: 0 },
      opacity: 0,
      animation: {
        curve: curves.springMotion(0.65, 0.88),
        keyframes: [
          { scale: { x: 0, y: 0 }, opacity: 0, time: 0 },
          { scale: { x: 1.2, y: 1.2 }, opacity: 0.8, time: 0.7 },
          { scale: { x: 1, y: 1 }, opacity: 1, time: 1 }
        ]
      }
    };
  }

  /**
   * 语音输入提示动画
   */
  static voicePromptAnimation() {
    return {
      translate: { x: 0, y: 20 },
      opacity: 0,
      animation: {
        curve: curves.springMotion(0.75, 0.85)
      }
    };
  }

  /**
   * 语音级别指示器动画
   */
  static voiceLevelIndicator(level: number) {
    const normalizedLevel = Math.max(0, Math.min(1, level));
    const barCount = 5;
    const animations = [];
    
    for (let i = 0; i < barCount; i++) {
      const threshold = (i + 1) / barCount;
      const isActive = normalizedLevel >= threshold;
      
      animations.push({
        opacity: isActive ? 1 : 0.3,
        scale: { x: 1, y: isActive ? 1 : 0.5 },
        animation: {
          duration: 100,
          curve: Curve.EaseOut,
          delay: i * 20
        }
      });
    }
    
    return animations;
  }

  /**
   * 语音命令识别动画
   */
  static commandRecognitionAnimation() {
    return {
      borderColor: '#00FF00',
      borderWidth: 2,
      animation: {
        duration: 200,
        curve: curves.springCurve(400, 30),
        keyframes: [
          { borderWidth: 2, borderColor: '#00FF00', time: 0 },
          { borderWidth: 4, borderColor: '#00AA00', time: 0.5 },
          { borderWidth: 1, borderColor: 'transparent', time: 1 }
        ]
      }
    };
  }
}

/**
 * 高级语音动画类
 */
export class AdvancedVoiceAnimations {
  private static animationManager = AnimationManager.getInstance();

  /**
   * 3D语音波形动画
   */
  static create3DWaveform(amplitudes: number[]) {
    const waveforms = [];
    
    amplitudes.forEach((amplitude, index) => {
      const normalizedAmplitude = Math.max(0.1, amplitude);
      const delay = index * 30;
      
      waveforms.push({
        scale: { x: 1, y: normalizedAmplitude },
        translate: { x: index * 8, y: 0 },
        animation: {
          duration: 200,
          curve: curves.springMotion(0.7, 0.9),
          delay: delay
        }
      });
    });
    
    return waveforms;
  }

  /**
   * 语音能量环动画
   */
  static voiceEnergyRing(energy: number) {
    const normalizedEnergy = Math.max(0, Math.min(1, energy));
    const ringCount = 3;
    const animations = [];
    
    for (let i = 0; i < ringCount; i++) {
      const scale = 1 + (normalizedEnergy * (i + 1) * 0.2);
      const opacity = normalizedEnergy * (1 - i * 0.2);
      
      animations.push({
        scale: { x: scale, y: scale },
        opacity: opacity,
        animation: {
          duration: 300,
          curve: Curve.EaseOut,
          delay: i * 50
        }
      });
    }
    
    return animations;
  }

  /**
   * 语音频谱动画
   */
  static voiceSpectrumAnimation(frequencies: number[]) {
    const bars = [];
    
    frequencies.forEach((frequency, index) => {
      const height = Math.max(0.1, frequency);
      const hue = (index / frequencies.length) * 360;
      
      bars.push({
        scale: { x: 1, y: height },
        backgroundColor: `hsl(${hue}, 70%, 60%)`,
        animation: {
          duration: 100,
          curve: Curve.EaseOut
        }
      });
    });
    
    return bars;
  }

  /**
   * 语音情感动画
   */
  static voiceEmotionAnimation(emotion: 'happy' | 'sad' | 'excited' | 'calm') {
    const emotionConfigs = {
      happy: {
        scale: { x: 1.2, y: 1.2 },
        color: '#FFD700',
        duration: 300
      },
      sad: {
        scale: { x: 0.9, y: 0.9 },
        color: '#87CEEB',
        duration: 500
      },
      excited: {
        scale: { x: 1.3, y: 1.3 },
        color: '#FF6B6B',
        duration: 200
      },
      calm: {
        scale: { x: 1.05, y: 1.05 },
        color: '#98FB98',
        duration: 800
      }
    };
    
    const config = emotionConfigs[emotion];
    
    return {
      scale: config.scale,
      backgroundColor: config.color,
      animation: {
        duration: config.duration,
        curve: curves.springMotion(0.6, 0.8),
        playMode: PlayMode.Alternate,
        iterations: 2
      }
    };
  }

  /**
   * 语音反馈粒子效果
   */
  static voiceFeedbackParticles() {
    const particles = [];
    const particleCount = 12;
    
    for (let i = 0; i < particleCount; i++) {
      const angle = (i / particleCount) * 2 * Math.PI;
      const radius = 30 + Math.random() * 20;
      const x = Math.cos(angle) * radius;
      const y = Math.sin(angle) * radius;
      
      particles.push({
        translate: { x, y },
        opacity: 0,
        scale: { x: 0.3, y: 0.3 },
        animation: {
          duration: 800,
          curve: Curve.FastOutSlowIn,
          delay: Math.random() * 300
        }
      });
    }
    
    return particles;
  }
}

/**
 * 语音动画工具类
 */
export class VoiceAnimationUtils {
  private static animationManager = AnimationManager.getInstance();

  /**
   * 应用语音状态动画
   */
  static applyVoiceStateAnimation(
    component: any,
    state: VoiceAnimationState,
    params?: any
  ) {
    let animation;
    
    switch (state) {
      case VoiceAnimationState.LISTENING:
        animation = VoiceAnimations.breathingAnimation();
        break;
      case VoiceAnimationState.PROCESSING:
        animation = VoiceAnimations.processingSpinAnimation();
        break;
      case VoiceAnimationState.SPEAKING:
        animation = VoiceAnimations.ttsPlayingAnimation();
        break;
      case VoiceAnimationState.ERROR:
        animation = VoiceAnimations.recognitionErrorAnimation();
        break;
      default:
        return;
    }
    
    if (component && animation) {
      Logger.info('VoiceAnimationUtils', `应用语音${state}动画`);
    }
  }

  /**
   * 创建自适应语音动画
   */
  static createAdaptiveVoiceAnimation(audioLevel: number, noiseLevel: number) {
    const adjustedLevel = Math.max(0, audioLevel - noiseLevel);
    const intensity = Math.min(1, adjustedLevel * 2);
    
    return {
      scale: { x: 1 + intensity * 0.3, y: 1 + intensity * 0.2 },
      opacity: 0.7 + intensity * 0.3,
      animation: {
        duration: 100 + intensity * 100,
        curve: curves.springMotion(0.5 + intensity * 0.3, 0.7 + intensity * 0.2)
      }
    };
  }

  /**
   * 创建语音同步动画
   */
  static createVoiceSyncAnimation(audioData: number[], sampleRate: number) {
    const animations = [];
    const frameDuration = 1000 / 60; // 60fps
    
    audioData.forEach((sample, index) => {
      const time = (index / sampleRate) * 1000;
      const frame = Math.floor(time / frameDuration);
      
      animations.push({
        frame,
        amplitude: Math.abs(sample),
        animation: {
          duration: frameDuration,
          curve: Curve.Linear
        }
      });
    });
    
    return animations;
  }

  /**
   * 获取语音主题适配动画
   */
  static getThemeAdaptedVoiceAnimation(isDark: boolean) {
    const lightTheme = {
      backgroundColor: '#FFFFFF',
      borderColor: '#E0E0E0',
      shadowColor: '#000000'
    };
    
    const darkTheme = {
      backgroundColor: '#1E1E1E',
      borderColor: '#404040',
      shadowColor: '#FFFFFF'
    };
    
    return this.animationManager.getThemeAdaptedParams(lightTheme, darkTheme);
  }
}