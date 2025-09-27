import { audio } from '@kit.AudioKit';
import { Logger } from '../utils/Logger';

const TAG = 'AudioCapturer';

/**
 * Audio collector tool
 */
interface GeneratedObjectLiteralInterface_1 {
  samplingRate: audio.AudioSamplingRate;
  channels: audio.AudioChannel;
  sampleFormat: audio.AudioSampleFormat;
  encodingType: audio.AudioEncodingType;
}

interface GeneratedObjectLiteralInterface_2 {
  source: audio.SourceType;
  capturerFlags: number;
}

interface GeneratedObjectLiteralInterface_3 {
  streamInfo: GeneratedObjectLiteralInterface_1;
  capturerInfo: GeneratedObjectLiteralInterface_2;
}

export default class AudioCapturer {
  /**
   * Collector object
   */
  private mAudioCapturer: audio.AudioCapturer | null = null;

  /**
   * Audio Data Callback Method
   */
  private mDataCallBack: ((data: ArrayBuffer) => void) | null = null;

  /**
   * Indicates whether recording data can be obtained.
   */
  private mCanWrite: boolean = true;

  /**
   * Audio stream information
   */
  private audioStreamInfo: GeneratedObjectLiteralInterface_1 = {
    samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
    channels: audio.AudioChannel.CHANNEL_1,
    sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
    encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
  }

  /**
   * Audio collector information
   */
  private audioCapturerInfo: GeneratedObjectLiteralInterface_2 = {
    source: audio.SourceType.SOURCE_TYPE_MIC,
    capturerFlags: 0
  }

  /**
   * Audio Collector Option Information
   */
  private audioCapturerOptions: GeneratedObjectLiteralInterface_3 = {
    streamInfo: this.audioStreamInfo,
    capturerInfo: this.audioCapturerInfo
  }

  /**
   *  Initialize
   * @param audioListener
   */
  public async init(dataCallBack: (data: ArrayBuffer) => void) {
    if (null != this.mAudioCapturer) {
      Logger.error(TAG, 'AudioCapturerUtil already init');
      return;
    }
    this.mDataCallBack = dataCallBack;
    try {
      this.mAudioCapturer = await audio.createAudioCapturer(this.audioCapturerOptions)
    } catch (error) {
      Logger.error(TAG, `AudioCapturerUtil init createAudioCapturer failed, code is ${error.code}, message is ${error.message}`);
    }
  }

  /**
   * start recording
   */
  public async start() {
    Logger.info(TAG, 'AudioCapturerUtil start');
    let stateGroup = [audio.AudioState.STATE_PREPARED, audio.AudioState.STATE_PAUSED, audio.AudioState.STATE_STOPPED];
    if (null === this.mAudioCapturer) {
      Logger.error(TAG, 'AudioCapturerUtil have not init');
      return;
    }
    if (stateGroup.indexOf(this.mAudioCapturer.state) === -1) {
      Logger.error(TAG, 'AudioCapturerUtil start failed');
      return;
    }
    this.mCanWrite = true;
    await this.mAudioCapturer.start();
    
    // 使用定时器而不是while循环，避免疯狂读取
    // 16kHz采样率，每20ms读取一次，确保音频流连续性
    const readInterval = 20; // 20ms间隔
    this.startAudioReadingLoop(readInterval);
  }
  
  /**
   * 音频读取循环，使用定时器控制读取节奏
   */
  private startAudioReadingLoop(intervalMs: number): void {
    if (!this.mCanWrite || !this.mAudioCapturer) {
      return;
    }
    
    setTimeout(async () => {
      try {
        if (!this.mCanWrite || !this.mAudioCapturer) {
          Logger.info(TAG, 'AudioCapturerUtil reading stopped');
          return;
        }
        
        // 获取当前可用的音频数据
        let bufferSize = await this.mAudioCapturer.getBufferSize();
        let buffer: ArrayBuffer = await this.mAudioCapturer.read(bufferSize, true); // 使用同步读取
        
        if (null === this.mDataCallBack) {
          Logger.error(TAG, 'AudioCapturerUtil callback is null');
          return;
        }
        
        // 只有当缓冲区有数据时才回调
        if (buffer && buffer.byteLength > 0) {
          Logger.info(TAG, `读取音频数据: ${buffer.byteLength} bytes`);
          this.mDataCallBack(buffer);
        }
        
        // 继续下一次读取
        this.startAudioReadingLoop(intervalMs);
        
      } catch (error) {
        Logger.error(TAG, `AudioCapturerUtil read error: ${JSON.stringify(error)}`);
        // 出错后也要继续尝试，直到停止
        if (this.mCanWrite) {
          this.startAudioReadingLoop(intervalMs);
        }
      }
    }, intervalMs);
  }

  /**
   * stop recording
   */
  public async stop() {
    if (null === this.mAudioCapturer) {
      Logger.error(TAG, 'AudioCapturerUtil have not init');
      return;
    }
    if (this.mAudioCapturer.state !== audio.AudioState.STATE_RUNNING && this.mAudioCapturer.state !== audio.AudioState.STATE_PAUSED) {
      Logger.error(TAG, 'AudioCapturerUtil stop Capturer is not running or paused');
      return;
    }
    this.mCanWrite = false;
    await this.mAudioCapturer.stop();
    if (Number(this.mAudioCapturer.state) == audio.AudioState.STATE_STOPPED) {
      Logger.info(TAG, 'AudioCapturerUtil Capturer stopped');
    } else {
      Logger.error(TAG, 'Capturer stop failed');
    }
  }

  /**
   * release
   */
  public async release() {
    if (null === this.mAudioCapturer) {
      Logger.error(TAG, 'AudioCapturerUtil have not init');
      return;
    }
    if (this.mAudioCapturer.state === audio.AudioState.STATE_RELEASED || this.mAudioCapturer.state === audio.AudioState.STATE_NEW) {
      Logger.error(TAG, 'Capturer already released');
      return;
    }
    await this.mAudioCapturer.release();
    this.mAudioCapturer = null;
    if (this.mAudioCapturer === null) {
      Logger.info(TAG, 'Capturer released');
    } else {
      Logger.error(TAG, 'Capturer release failed');
    }
  }

  /**
   * 销毁音频捕获器
   */
  public async destroy(): Promise<void> {
    try {
      // 停止录音
      if (this.mAudioCapturer && this.mAudioCapturer.state === audio.AudioState.STATE_RUNNING) {
        await this.stop();
      }
      
      // 释放资源
      await this.release();
      
      // 清理回调
      this.mDataCallBack = null;
      this.mCanWrite = false;
      
      Logger.info(TAG, 'AudioCapturer destroyed successfully');
    } catch (error) {
      Logger.error(TAG, `Failed to destroy AudioCapturer: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 设置音频数据回调
   */
  public setAudioDataCallback(callback: (data: ArrayBuffer) => void): void {
    this.mDataCallBack = callback;
  }

  /**
   * 获取当前状态
   */
  public getState(): audio.AudioState | null {
    return this.mAudioCapturer ? this.mAudioCapturer.state : null;
  }

  /**
   * 检查是否正在录音
   */
  public isRecording(): boolean {
    return !!this.mCanWrite && !!this.mAudioCapturer && this.mAudioCapturer.state === audio.AudioState.STATE_RUNNING;
  }
}