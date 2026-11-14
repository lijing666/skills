import { Drawer, Modal, Space } from "antd";

// 状态栏附属浮层 Feature：发布确认弹框 + 版本历史抽屉（判据正源: references/page-splitting.md——
// 与状态栏触发的发布/历史同属一个状态闭环，合并一个 Feature；写回 published 归入口）
const VERSIONS = [
  { version: "v2.0", note: "当前草稿基线" },
  { version: "v1.9", note: "新增下单校验规则" },
  { version: "v1.8", note: "调整客户字段说明" }
];

type Props = {
  publishOpen: boolean;
  historyOpen: boolean;
  onPublish: () => void;
  onPublishCancel: () => void;
  onHistoryClose: () => void;
};

export default function StatusDialogs({ publishOpen, historyOpen, onPublish, onPublishCancel, onHistoryClose }: Props) {
  return (
    <>
      <Modal
        title="发布工作台"
        open={publishOpen}
        okText="发布"
        cancelText="取消"
        onOk={onPublish}
        onCancel={onPublishCancel}
      >
        <p>发布后当前草稿将固化为基线 v2.1，已发布版本不可直接修改。</p>
      </Modal>

      <Drawer title="版本历史" open={historyOpen} onClose={onHistoryClose}>
        <Space orientation="vertical" style={{ width: "100%" }} size={8}>
          {VERSIONS.map((item) => (
            <div key={item.version} style={{ display: "flex", justifyContent: "space-between" }}>
              <span>{item.version}</span>
              <span className="jjui-pagination__meta">{item.note}</span>
            </div>
          ))}
        </Space>
      </Drawer>
    </>
  );
}
