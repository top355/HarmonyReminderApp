import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';

interface ReminderItem {
  id: number;
  reminderId: number;
  hour: number;
  minute: number;
  label: string;
  repeat: boolean;
}

const BUNDLE_NAME = 'com.example.harmonyreminder';
const ABILITY_NAME = 'EntryAbility';

@Entry
@Component
struct Index {
  @State reminders: ReminderItem[] = [];
  @State selectedHour: number = 8;
  @State selectedMinute: number = 0;
  @State inputLabel: string = '';
  @State isDaily: boolean = true;
  @State nextId: number = 1;

  private context = getContext(this) as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    // Load saved reminders from preferences
    try {
      const prefs = await preferences.getPreferences(this.context, 'reminders');
      const data = await prefs.get('list', '[]') as string;
      const list: ReminderItem[] = JSON.parse(data) as ReminderItem[];
      this.reminders = list;
      this.nextId = list.length > 0 ? Math.max(...list.map(r => r.id)) + 1 : 1;
    } catch (e) {
      console.error('Failed to load reminders: ' + (e as Error).message);
    }
  }

  async saveToPrefs(): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'reminders');
      await prefs.put('list', JSON.stringify(this.reminders));
      await prefs.flush();
    } catch (e) {
      console.error('Failed to save reminders: ' + (e as Error).message);
    }
  }

  getNextDate(hour: number, minute: number): Date {
    const now = new Date();
    const target = new Date();
    target.setHours(hour, minute, 0, 0);
    if (target.getTime() <= now.getTime()) {
      target.setDate(target.getDate() + 1);
    }
    return target;
  }

  async addReminder(): Promise<void> {
    const id = this.nextId++;
    const label = this.inputLabel.trim() || '提醒时间到了';

    try {
      let reminderId: number;

      if (this.isDaily) {
        // Daily repeat: use Alarm type with all 7 days
        const alarm: reminderAgentManager.ReminderRequestAlarm = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
          hour: this.selectedHour,
          minute: this.selectedMinute,
          daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
          title: '提醒',
          content: label,
          actionButton: [
            {
              title: '关闭',
              type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
            }
          ],
          wantAgent: {
            pkgName: BUNDLE_NAME,
            abilityName: ABILITY_NAME
          },
          maxScreenWantAgent: {
            pkgName: BUNDLE_NAME,
            abilityName: ABILITY_NAME
          },
          ringDuration: 10,
          snoozeTimes: 2,
          timeInterval: 300,
          notificationId: id + 1000,
          slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
        };
        reminderId = await reminderAgentManager.publishReminder(alarm);
      } else {
        // One-time: use Calendar type with specific date
        const date = this.getNextDate(this.selectedHour, this.selectedMinute);
        const calendar: reminderAgentManager.ReminderRequestCalendar = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
          dateTime: {
            year: date.getFullYear(),
            month: date.getMonth() + 1,
            day: date.getDate(),
            hour: this.selectedHour,
            minute: this.selectedMinute,
            second: 0
          },
          title: '提醒',
          content: label,
          actionButton: [
            {
              title: '关闭',
              type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
            }
          ],
          wantAgent: {
            pkgName: BUNDLE_NAME,
            abilityName: ABILITY_NAME
          },
          maxScreenWantAgent: {
            pkgName: BUNDLE_NAME,
            abilityName: ABILITY_NAME
          },
          ringDuration: 10,
          snoozeTimes: 2,
          timeInterval: 300,
          notificationId: id + 1000,
          slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
        };
        reminderId = await reminderAgentManager.publishReminder(calendar);
      }

      this.reminders.push({
        id,
        reminderId,
        hour: this.selectedHour,
        minute: this.selectedMinute,
        label,
        repeat: this.isDaily
      });
      await this.saveToPrefs();
      this.inputLabel = '';

      const timeStr = this.formatTime(this.selectedHour, this.selectedMinute);
      promptAction.showToast({
        message: `已添加提醒 ${timeStr}`,
        duration: 2000
      });
    } catch (e) {
      const err = e as BusinessError;
      promptAction.showToast({
        message: `添加失败: ${err.message ?? err.code}`,
        duration: 3000
      });
    }
  }

  async deleteReminder(item: ReminderItem): Promise<void> {
    try {
      await reminderAgentManager.cancelReminder(item.reminderId);
    } catch (e) {
      // Reminder may already be gone, ignore
    }
    this.reminders = this.reminders.filter(r => r.id !== item.id);
    await this.saveToPrefs();
  }

  formatTime(h: number, m: number): string {
    return `${h < 10 ? '0' + h : h}:${m < 10 ? '0' + m : m}`;
  }

  build(): void {
    Column() {
      // Title bar
      Text('提醒')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(16)

      // Time picker
      TimePicker({
        selected: new Date(2026, 0, 1, this.selectedHour, this.selectedMinute)
      })
        .onChange((value: TimePickerResult) => {
          this.selectedHour = value.hour;
          this.selectedMinute = value.minute;
        })
        .margin({ top: 10, bottom: 10 })

      // Label input
      TextInput({
        text: this.inputLabel,
        placeholder: '提醒内容（可选）'
      })
        .width('80%')
        .height(48)
        .margin({ bottom: 12 })
        .onChange((value: string) => {
          this.inputLabel = value;
        })

      // Repeat toggle
      Row() {
        Text('每天重复')
          .fontSize(16)
        Toggle({ type: ToggleType.Switch, isOn: this.isDaily })
          .onChange((isOn: boolean) => {
            this.isDaily = isOn;
          })
      }
      .width('80%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 16 })

      // Add button
      Button('添加提醒')
        .width('80%')
        .height(48)
        .fontSize(18)
        .type(ButtonType.Capsule)
        .backgroundColor('#007DFF')
        .margin({ bottom: 20 })
        .onClick(() => {
          this.addReminder();
        })

      // Divider
      Divider()
        .color('#E0E0E0')
        .width('90%')
        .margin({ bottom: 8 })

      // Reminder list
      if (this.reminders.length === 0) {
        Text('暂无提醒')
          .fontSize(16)
          .fontColor('#999999')
          .margin({ top: 40 })
      } else {
        Scroll() {
          Column() {
            ForEach(this.reminders.slice().sort((a: ReminderItem, b: ReminderItem) => {
              return a.hour !== b.hour ? a.hour - b.hour : a.minute - b.minute;
            }), (item: ReminderItem) => {
              Row() {
                Column() {
                  Text(this.formatTime(item.hour, item.minute))
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                  Text(item.label)
                    .fontSize(14)
                    .fontColor('#666666')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(item.repeat ? '每天' : '单次')
                  .fontSize(13)
                  .fontColor('#999999')
                  .margin({ right: 12 })

                Button('删除')
                  .fontSize(14)
                  .height(36)
                  .type(ButtonType.Capsule)
                  .backgroundColor('#FF453A')
                  .fontColor('#FFFFFF')
                  .onClick(() => {
                    this.deleteReminder(item);
                  })
              }
              .width('90%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F5F5F5')
              .margin({ bottom: 8 })
              .alignItems(VerticalAlign.Center)
            }, (item: ReminderItem) => item.id.toString())
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
